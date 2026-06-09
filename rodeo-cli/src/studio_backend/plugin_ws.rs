use super::connection;
use crate::master::SharedBackendState;
use rodeo_proto as proto;
use proto::ProcessState;
use crate::runtime::mcp as mcp_service;
use futures_util::{SinkExt, StreamExt};
use hyper_tungstenite::tungstenite::Message;
use serde_json::Value;
use tokio::sync::mpsc;
use tracing::{info, debug, Instrument};

/// Stamp `session_guid` on the given VM from the plugin's self-reported
/// handshake value. The plugin has `flags.SESSION_GUID` baked in at install
/// time and forwards it on its first `StudioStateMsg`. Master looks up the
/// matching `StudioInstanceInfo` (keyed by session_guid), stamps the VM
/// synchronously, and transitions the instance to "connected". Returns
/// true if the session was stamped.
fn try_claim_session_from_handshake(guard: &mut crate::master::BackendState, vm_id: &str) -> bool {
    let already_stamped = guard.vms.get(vm_id)
        .map(|vm| vm.session_guid.is_some())
        .unwrap_or(false);
    if already_stamped { return false; }
    let Some(reported) = guard.vms.get(vm_id)
        .and_then(|vm| vm.state.as_ref())
        .and_then(|s| s.session_guid.clone())
    else { return false; };

    // Plugin self-reports an id it baked in at install time. Trust it iff
    // we actually spawned something with that id (studio_instances).
    let matched = guard.studio_instances.contains_key(&reported);
    if !matched { return false; }

    if let Some(inst) = guard.studio_instances.get_mut(&reported) {
        if inst.status == "launching" {
            inst.status = "connected".to_string();
        }
    }
    if let Some(vm) = guard.vms.get_mut(vm_id) {
        vm.session_guid = Some(reported);
    }
    if let Some(ref notify) = guard.snapshot_trigger {
        notify.notify_one();
    }
    true
}

/// Shared handler for plugin-reported run termination (Done or Killed).
/// Both outcomes follow the same shape: check whether the run is local to
/// this backend; if so, forward the typed event to the run client and
/// complete the run locally; otherwise, relay the PluginMessage upstream.
async fn handle_run_finished(
    state: &SharedBackendState,
    vm_id: &str,
    eid: &str,
    new_state: ProcessState,
    pm_for_relay: proto::PluginMessage,
    forward: impl FnOnce(&connection::VmConnection, &str),
) {
    let mut guard = state.lock().await;
    let is_local = guard.vms.get(vm_id)
        .map(|vm| vm.active_runs.contains_key(eid))
        .unwrap_or(false);

    if is_local {
        if let Some(vm) = guard.vms.get(vm_id) {
            forward(vm, eid);
        }
        guard.complete_run(eid, vm_id, new_state);
    } else {
        let relay_tx = guard.relay_tx.clone();
        drop(guard);
        if let Some(tx) = relay_tx {
            let _ = tx.send(wrap_vm_plugin_message(vm_id, pm_for_relay));
        }
    }
}

/// Wrap a typed plugin message as a proto BackendMessage::VmPluginMessage for relay to master.
fn wrap_vm_plugin_message(vm_id: &str, message: proto::PluginMessage) -> proto::BackendMessage {
    proto::BackendMessage {
        msg: Some(proto::backend_message::Msg::VmPluginMessage(Box::new(proto::VmPluginMessage {
            vm_id: vm_id.to_string(),
            message: buffa::MessageField::some(message),
            ..Default::default()
        }))),
        ..Default::default()
    }
}

/// Send a typed ClientRpcResponse to the plugin, JSON-encoded for the websocket.
fn send_rpc_response(
    studio_tx: &mpsc::UnboundedSender<String>,
    resp: proto::runtime_types::ClientRpcResponse,
) {
    let server_msg = proto::ServerMessage {
        msg: Some(proto::server_message::Msg::RpcResponse(Box::new(resp))),
        ..Default::default()
    };
    let _ = studio_tx.send(serde_json::to_string(&server_msg).unwrap());
}

/// Build an error ClientRpcResponse for a given call id.
fn error_response(eid: &str, rpc_id: &str, message: String) -> proto::runtime_types::ClientRpcResponse {
    proto::runtime_types::ClientRpcResponse {
        id: rpc_id.to_string(),
        execution_id: eid.to_string(),
        res: Some(proto::runtime_types::client_rpc_response::Res::Error(message)),
        ..Default::default()
    }
}

/// Handle a studio (plugin) client connection.
/// The first message is the initial studio_state (parsed by caller).
pub async fn handle_studio_client<S, R>(
    ws_tx: &mut S,
    ws_rx: &mut R,
    state: SharedBackendState,
    first_msg: &Value,
) where
    S: SinkExt<Message> + Unpin,
    R: StreamExt<Item = Result<Message, hyper_tungstenite::tungstenite::Error>> + Unpin,
{
    let (studio_tx, mut studio_rx) = mpsc::unbounded_channel::<String>();

    // Parse initial state from the first message (proto format: { "studioState": { ... } })
    let initial_state: Option<proto::StudioStateMsg> = first_msg.get("studioState")
        .and_then(|s| serde_json::from_value(s.clone()).ok());

    let vm_id = initial_state.as_ref()
        .map(|s| s.vm_id.clone())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| uuid::Uuid::new_v4().to_string());

    let game_name = initial_state.as_ref()
        .map(|s| s.game_name.clone())
        .unwrap_or_default();
    let place_id = initial_state.as_ref()
        .map(|s| s.place_id)
        .unwrap_or(0);

    let vm_id_short = vm_id[..8.min(vm_id.len())].to_string();
    let dom = initial_state.as_ref().map(|s| if s.dom.is_empty() { "?" } else { s.dom.as_str() }).unwrap_or("?").to_string();
    let span = tracing::info_span!("studio", id = vm_id_short.as_str(), dom = dom.as_str());

    async move {

    let initial_mode = initial_state.as_ref().map(|s| if s.mode.is_empty() { "?" } else { s.mode.as_str() }).unwrap_or("?");
    let initial_mcp_studio_id = initial_state.as_ref().and_then(|s| s.mcp_studio_id.as_deref()).unwrap_or("none");
    info!(
        universe = game_name.as_str(),
        place_id,
        mode = initial_mode,
        mcp_studio_id = &initial_mcp_studio_id[..8.min(initial_mcp_studio_id.len())],
        "vm connected"
    );

    // Register VM
    {
        let mut guard = state.lock().await;

        if let Some(old_vm) = guard.vms.get_mut(&vm_id) {
            if old_vm.connected {
                old_vm.disconnect();
            }
        }

        let mut conn = connection::VmConnection::new(vm_id.clone(), studio_tx.clone());
        if let Some(ref s) = initial_state {
            conn.update_state(s.clone());
        }
        guard.vms.insert(vm_id.clone(), conn);
        guard.process_pending();

        // Identity pairing: the plugin reports its baked `session_guid` on the
        // first message (see flags.SESSION_GUID). Match it to a known
        // StudioInstanceInfo and stamp synchronously — no polling, no races.
        //
        // Fallback: if the plugin didn't send one (e.g. an older build or a
        // manually-installed plugin that wasn't spawned by rodeo), leave the
        // VM un-stamped. It still connects; it just isn't scoped to a session
        // for routing. Published-place launches where the plugin IS rodeo-
        // installed always send the guid, so this covers only manual installs.
        let _ = try_claim_session_from_handshake(&mut *guard, &vm_id);

        // Relay vm_connect to master
        if let Some(ref relay_tx) = guard.relay_tx {
            let state_json = initial_state.as_ref()
                .map(|s| serde_json::to_string(s).unwrap_or_default())
                .unwrap_or_default();
            let _ = relay_tx.send(proto::BackendMessage {
                msg: Some(proto::backend_message::Msg::VmConnect(Box::new(proto::VmConnect {
                    vm_id: vm_id.clone(),
                    state_json,
                    ..Default::default()
                }))),
                ..Default::default()
            });
        }

        // Send welcome
        let welcome = proto::ServerMessage {
            msg: Some(proto::server_message::Msg::Welcome(Box::new(proto::WelcomeMsg {
                version: env!("CARGO_PKG_VERSION").to_string(),
                ..Default::default()
            }))),
            ..Default::default()
        };
        let _ = ws_tx.send(Message::Text(serde_json::to_string(&welcome).unwrap().into())).await;
    }

    // Message loop
    loop {
        tokio::select! {
            // Server → plugin (run commands, rpc responses)
            msg = studio_rx.recv() => {
                match msg {
                    Some(text) => {
                        if ws_tx.send(Message::Text(text.into())).await.is_err() {
                            break;
                        }
                    }
                    None => break,
                }
            }
            // Plugin → server — plugin only sends typed PluginMessage variants post-migration.
            msg = ws_rx.next() => {
                match msg {
                    Some(Ok(Message::Text(text))) => {
                        match serde_json::from_str::<proto::PluginMessage>(&text) {
                            Ok(pm) if pm.msg.is_some() => {
                                handle_plugin_message(pm, &vm_id, &state, &studio_tx).await;
                            }
                            Ok(_) => {
                                debug!("ignoring PluginMessage with empty msg oneof");
                            }
                            Err(e) => {
                                tracing::warn!(error = %e, "failed to decode plugin message");
                            }
                        }
                    }
                    Some(Ok(Message::Close(_))) | None => break,
                    _ => {}
                }
            }
        }
    }

    // Disconnect
    {
        let guard = state.lock().await;
        let mode = guard.vms.get(&vm_id).and_then(|vm| vm.mode()).unwrap_or("?");
        let dom = guard.vms.get(&vm_id).and_then(|vm| vm.dom()).unwrap_or("?");
        info!(mode, dom, "vm disconnected");
    }

    let mut guard = state.lock().await;
    if let Some(ref relay_tx) = guard.relay_tx {
        let _ = relay_tx.send(proto::BackendMessage {
            msg: Some(proto::backend_message::Msg::VmDisconnect(Box::new(proto::VmDisconnect {
                vm_id: vm_id.clone(),
                ..Default::default()
            }))),
            ..Default::default()
        });
    }
    if let Some(vm) = guard.vms.get_mut(&vm_id) {
        vm.disconnect();
    }
    guard.vms.remove(&vm_id);
    if let Some(ref notify) = guard.snapshot_trigger {
        notify.notify_one();
    }
    guard.process_pending();

    }.instrument(span).await
}

/// Handle a proto PluginMessage from the plugin.
async fn handle_plugin_message(
    plugin_msg: proto::PluginMessage,
    vm_id: &str,
    state: &SharedBackendState,
    studio_tx: &mpsc::UnboundedSender<String>,
) {
    // Clone for relay before destructuring (move-semantics of the oneof makes the original pm unusable).
    let pm_for_relay = plugin_msg.clone();
    let msg = match plugin_msg.msg {
        Some(m) => m,
        None => return,
    };

    match msg {
        proto::plugin_message::Msg::StudioState(ss) => {
            let mut guard = state.lock().await;
            if let Some(vm) = guard.vms.get_mut(vm_id) {
                if let Some(diff) = vm.update_state(*ss.clone()) {
                    info!(changes = diff.as_str(), "state changed");
                }
            }

            // Subsequent-update path: if the VM wasn't stamped at handshake
            // (older plugin, or the session_guid field arrived in a later
            // update), retry the handshake claim here.
            try_claim_session_from_handshake(&mut *guard, vm_id);

            guard.process_pending();

            if let Some(ref relay_tx) = guard.relay_tx {
                let _ = relay_tx.send(wrap_vm_plugin_message(vm_id, pm_for_relay));
            }
        }
        proto::plugin_message::Msg::Rpc(call) => {
            // Plugin now sends typed ClientRpcCall directly — no method/params_json translation.
            let eid = call.execution_id.clone();
            let rpc_id = call.id.clone();

            // mcp.call is server-context; dispatch server-side and return a typed response.
            // All other variants forward to the run-client.
            match call.req {
                Some(proto::runtime_types::client_rpc_call::Req::McpCall(_)) => {
                    debug!(method = "mcp.call", eid = &eid[..8.min(eid.len())], "rpc (server)");
                    let state_clone = state.clone();
                    let studio_tx_clone = studio_tx.clone();
                    let vm_id = vm_id.to_string();
                    let call_owned = *call;
                    tokio::spawn(async move {
                        let response = dispatch_mcp(&state_clone, &vm_id, call_owned).await;
                        send_rpc_response(&studio_tx_clone, response);
                    });
                }
                _ => {
                    debug!(eid = &eid[..8.min(eid.len())], "rpc (client)");
                    let guard = state.lock().await;
                    let is_local = guard.vms.get(vm_id)
                        .map(|vm| vm.active_runs.contains_key(eid.as_str()))
                        .unwrap_or(false);

                    if is_local {
                        if let Some(vm) = guard.vms.get(vm_id) {
                            vm.forward_rpc_call(&eid, *call);
                        }
                    } else if let Some(ref relay_tx) = guard.relay_tx {
                        // Multi-node relay: forward the typed PluginMessage.
                        let _ = relay_tx.send(wrap_vm_plugin_message(vm_id, pm_for_relay));
                    } else {
                        tracing::warn!(eid = &eid[..8.min(eid.len())], rpc_id = &rpc_id[..8.min(rpc_id.len())], vm_id, "rpc call with no active run and no relay — dropping");
                    }
                }
            }
        }
        proto::plugin_message::Msg::Done(done) => {
            let eid = done.execution_id.clone();
            let new_state = if done.success { ProcessState::PROCESS_STATE_DONE } else { ProcessState::PROCESS_STATE_ERROR };
            let done_owned = *done;
            handle_run_finished(
                state, vm_id, &eid, new_state, pm_for_relay,
                move |vm, eid| { vm.forward_execution_done(eid, done_owned); },
            ).await;
        }
        proto::plugin_message::Msg::Killed(killed) => {
            let eid = killed.execution_id.clone();
            let killed_owned = *killed;
            handle_run_finished(
                state, vm_id, &eid, ProcessState::PROCESS_STATE_KILLED, pm_for_relay,
                move |vm, eid| { vm.forward_execution_killed(eid, killed_owned); },
            ).await;
        }
    }
}

/// Dispatch a server-context RPC (currently: `mcp.call`). Returns a typed ClientRpcResponse.
async fn dispatch_mcp(
    state: &SharedBackendState,
    vm_id: &str,
    call: proto::runtime_types::ClientRpcCall,
) -> proto::runtime_types::ClientRpcResponse {
    use proto::runtime_types::client_rpc_call::Req;
    use proto::runtime_types::client_rpc_response::Res;

    let eid = call.execution_id.clone();
    let rpc_id = call.id.clone();

    let mcp_req = match call.req {
        Some(Req::McpCall(r)) => r,
        _ => return error_response(&eid, &rpc_id, "dispatch_mcp expects McpCallRequest".into()),
    };

    let mcp_arc = { state.lock().await.mcp.clone() };

    // Wait for MCP unification (mcp_studio_id resolved) up to ~10 seconds.
    let mcp_sid = {
        let guard = state.lock().await;
        guard.vms.get(vm_id).and_then(|vm| vm.state.as_ref()).and_then(|s| s.mcp_studio_id.clone())
    };
    let mcp_sid = match mcp_sid {
        Some(sid) => sid,
        None => {
            debug!("waiting for MCP unification");
            let mut attempts = 0;
            loop {
                tokio::time::sleep(std::time::Duration::from_millis(500)).await;
                attempts += 1;
                let guard = state.lock().await;
                if let Some(sid) = guard.vms.get(vm_id).and_then(|vm| vm.state.as_ref()).and_then(|s| s.mcp_studio_id.clone()) {
                    break sid;
                }
                if attempts >= 20 {
                    return error_response(&eid, &rpc_id, "Timed out waiting for StudioMCP unification".into());
                }
            }
        }
    };

    let arguments: Value = serde_json::from_str(&mcp_req.arguments_json).unwrap_or(Value::Object(Default::default()));
    match mcp_service::handle_mcp_call(mcp_arc, &mcp_sid, &mcp_req.tool, &arguments).await {
        Ok(text) => proto::runtime_types::ClientRpcResponse {
            id: rpc_id,
            execution_id: eid,
            res: Some(Res::McpCall(Box::new(proto::runtime_types::McpCallResponse { result: text, ..Default::default() }))),
            ..Default::default()
        },
        Err(e) => error_response(&eid, &rpc_id, e),
    }
}
