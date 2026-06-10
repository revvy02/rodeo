//! gRPC service implementations for master server.
//!
//! Uses connectrpc-generated traits from proto/rodeo.proto.
//! Each streaming service uses a single bidirectional stream — registration/submission
//! is the first message, then the stream stays open for the relay loop.

use rodeo_proto as proto;

use crate::master::SharedMasterState;
use std::sync::Arc;
use std::pin::Pin;
use tokio::sync::{mpsc, watch};
use futures::stream::{Stream, StreamExt};
use connectrpc::{ConnectError, Context};
use buffa::view::OwnedView;

/// A registered backend connection on master.
pub struct BackendConnection {
    pub id: String,
    pub kind: String,
    pub name: String,
    pub tx: mpsc::UnboundedSender<proto::MasterMessage>,
    /// Watch channel for reactive state observation. Updated when StateSnapshot arrives.
    pub state_tx: watch::Sender<proto::StateSnapshot>,
    pub state_rx: watch::Receiver<proto::StateSnapshot>,
}

/// Unified service implementation for all gRPC services.
pub struct RodeoServices {
    pub state: SharedMasterState,
}

// ---------------------------------------------------------------------------
// BackendService
// ---------------------------------------------------------------------------

impl proto::BackendService for RodeoServices {
    async fn control(
        &self,
        _ctx: Context,
        mut requests: Pin<Box<dyn Stream<Item = Result<OwnedView<proto::BackendMessageView<'static>>, ConnectError>> + Send>>,
    ) -> Result<(Pin<Box<dyn Stream<Item = Result<proto::MasterMessage, ConnectError>> + Send>>, Context), ConnectError> {
        let state = self.state.clone();

        // First message must be Register
        let first = requests.next().await
            .ok_or_else(|| ConnectError::invalid_argument("expected RegisterRequest as first message"))?
            .map_err(|e| ConnectError::internal(format!("stream error: {e}")))?;

        let first_owned = first.to_owned_message();
        let register = match first_owned.msg {
            Some(proto::backend_message::Msg::Register(r)) => r,
            _ => return Err(ConnectError::invalid_argument("first message must be RegisterRequest")),
        };

        let backend_id = uuid::Uuid::new_v4().to_string();
        let kind = register.kind.clone();

        // Channel for master → backend messages
        let (master_tx, master_rx) = mpsc::unbounded_channel::<proto::MasterMessage>();

        // Store backend
        {
            let mut guard = state.lock().await;
            let (state_tx, state_rx) = watch::channel(proto::StateSnapshot::default());
            guard.backends.insert(backend_id.clone(), BackendConnection {
                id: backend_id.clone(),
                kind,
                name: register.name.clone(),
                tx: master_tx.clone(),
                state_tx,
                state_rx,
            });
        }

        tracing::info!(id = &backend_id[..8], kind = register.kind.as_str(), name = register.name.as_str(), "backend registered");

        // Send RegisterResponse as first MasterMessage.
        // master_id is the bootstrap UUID stamped by util::log_capture::init on
        // master startup (see main.rs → run_master). Propagating it through
        // registration lets backends include it as a tracing span field for
        // cross-host correlation.
        let master_id = state.lock().await.master_id.clone();
        let _ = master_tx.send(proto::MasterMessage {
            msg: Some(proto::master_message::Msg::Registered(Box::new(proto::RegisterResponse {
                id: backend_id.clone(),
                master_id,
                ..Default::default()
            }))),
            ..Default::default()
        });

        // Spawn relay loop: reads BackendMessages and processes them
        let relay_state = state.clone();
        let bid = backend_id.clone();
        let relay_master_tx = master_tx.clone();
        tokio::spawn(async move {
            while let Some(Ok(view)) = requests.next().await {
                let backend_msg = view.to_owned_message();
                if let Some(msg) = backend_msg.msg {
                    handle_backend_msg(msg, &relay_state, &bid, &relay_master_tx).await;
                }
            }

            // Backend disconnected — clean up
            tracing::info!(id = &bid[..8], "backend disconnected");
            let mut guard = relay_state.lock().await;
            guard.backends.remove(&bid);
        });

        // Return the master → backend stream
        let output_stream = tokio_stream::wrappers::UnboundedReceiverStream::new(master_rx)
            .map(|msg| Ok(msg));

        Ok((Box::pin(output_stream), Context::default()))
    }

    async fn send_file(
        &self,
        _ctx: Context,
        mut requests: Pin<Box<dyn Stream<Item = Result<OwnedView<proto::FileChunkView<'static>>, ConnectError>> + Send>>,
    ) -> Result<(proto::FileAck, Context), ConnectError> {
        // Forward each chunk directly to the run client — no reassembly on master
        while let Some(Ok(view)) = requests.next().await {
            let chunk = view.to_owned_message();
            let guard = self.state.lock().await;
            for run in guard.active_runs.values() {
                if run.execution_id == chunk.execution_id {
                    if chunk.is_last {
                        tracing::debug!(filename = chunk.filename.as_str(), "file forwarded to run client");
                    }
                    let _ = run.client_tx.send(crate::master::ClientMsg::FileChunk(chunk.clone()));
                    break;
                }
            }
        }

        Ok((proto::FileAck::default(), Context::default()))
    }
}

/// Handle a backend control message.
async fn handle_backend_msg(
    msg: proto::backend_message::Msg,
    state: &SharedMasterState,
    backend_id: &str,
    _master_tx: &mpsc::UnboundedSender<proto::MasterMessage>,
) {
    use proto::backend_message::Msg;
    match msg {
        Msg::Register(_) => {} // Already handled as first message
        Msg::VmConnect(vc_box) => {
            let vc = *vc_box;
            let vm_id = vc.vm_id;
            let vm_state: Option<proto::StudioStateMsg> = serde_json::from_str(&vc.state_json).ok();

            if let Some(ref s) = vm_state {
                let dom = if s.dom.is_empty() { "?" } else { s.dom.as_str() };
                let mode = if s.mode.is_empty() { "?" } else { s.mode.as_str() };
                tracing::info!(vm = &vm_id[..8.min(vm_id.len())], dom, mode, "uplifted vm");
            }

            // VM will be routable once the backend's snapshot includes it
            let mut guard = state.lock().await;
            guard.reconcile();
        }
        Msg::VmDisconnect(vd) => {
            let vm_id = &vd.vm_id;
            tracing::info!(vm = &vm_id[..8.min(vm_id.len())], "uplifted vm disconnected");
            let mut guard = state.lock().await;
            // Sweep active_runs for entries targeting the now-gone VM and
            // complete them as killed. Without this, `listProcesses` keeps
            // reporting them as "running" and subsequent `kill(pid)` calls
            // can't route (send_to_vm: no backend found).
            let orphaned: Vec<String> = guard.active_runs.values()
                .filter(|r| r.vm_id == *vm_id)
                .map(|r| r.execution_id.clone())
                .collect();
            for eid in orphaned {
                tracing::info!(execution_id = eid.as_str(), vm = &vm_id[..8.min(vm_id.len())], "vm disconnect: completing orphaned run as killed");
                guard.complete_run(&eid, proto::ProcessState::PROCESS_STATE_KILLED);
            }
            // Also drop any pending_runs that were waiting for this specific VM.
            guard.pending_runs.retain(|r| r.vm_id.as_deref() != Some(vm_id.as_str()));
            guard.reconcile();
        }
        Msg::VmPluginMessage(vm_plugin) => {
            // Backend relayed a typed PluginMessage. Dispatch by oneof case directly —
            // no JSON string-matching, no payload parsing.
            let vm_id = vm_plugin.vm_id;
            let message = match vm_plugin.message.into_option() {
                Some(m) => m,
                None => return,
            };
            let msg = match message.msg {
                Some(m) => m,
                None => return,
            };
            use proto::plugin_message::Msg as PluginMsg;
            match msg {
                PluginMsg::StudioState(_ss) => {
                    let mut guard = state.lock().await;
                    guard.reconcile();
                }
                PluginMsg::Rpc(call) => {
                    let eid = call.execution_id.clone();
                    let forwarded = {
                        let guard = state.lock().await;
                        guard.forward_rpc_call(&eid, (*call).clone())
                    };
                    if !forwarded {
                        // No run-client owns this execution — server-initiated (e.g. transition
                        // scripts). Dispatch with a one-shot RpcState using the server's env,
                        // then route the typed response back to the plugin via the backend.
                        let state_clone = state.clone();
                        let vm_id_owned = vm_id.clone();
                        tokio::spawn(async move {
                            // Server-initiated scripts (e.g. mode-transition scripts) are
                            // internal — their stdout/stderr bytes go nowhere. Give them
                            // a capture channel whose receiver we immediately drop, so
                            // the runtime's channel sends no-op. Any script that writes
                            // to stdout/stderr here is silently discarded, matching the
                            // "internal script" semantics.
                            let (capture_tx, _) = tokio::sync::mpsc::unbounded_channel();
                            let rpc_state = std::sync::Arc::new(tokio::sync::Mutex::new(
                                crate::runtime::RpcState::new(capture_tx),
                            ));
                            let response = crate::runtime::dispatch_client(rpc_state, &*call).await;
                            let server_msg = proto::ServerMessage {
                                msg: Some(proto::server_message::Msg::RpcResponse(Box::new(response))),
                                ..Default::default()
                            };
                            let guard = state_clone.lock().await;
                            guard.send_to_vm(&vm_id_owned, server_msg);
                        });
                    }
                }
                PluginMsg::Done(done) => {
                    let eid = done.execution_id.clone();
                    let success = done.success;
                    let mut guard = state.lock().await;
                    guard.forward_execution_done(&eid, *done);
                    let new_state = if !success { proto::ProcessState::PROCESS_STATE_ERROR } else { proto::ProcessState::PROCESS_STATE_DONE };
                    guard.complete_run(&eid, new_state);
                }
                PluginMsg::Killed(killed) => {
                    let eid = killed.execution_id.clone();
                    let mut guard = state.lock().await;
                    guard.forward_execution_killed(&eid, *killed);
                    guard.complete_run(&eid, proto::ProcessState::PROCESS_STATE_KILLED);
                }
            }
        }
        Msg::StateSnapshot(ss) => {
            let mut guard = state.lock().await;
            if let Some(backend) = guard.backends.get(backend_id) {
                let _ = backend.state_tx.send(*ss);
            }
            // Backend's VM snapshot changed — rerun the reconciliation so
            // pending runs route to newly-matched VMs and target_modes reflect
            // the current studio set.
            guard.reconcile();
        }
        Msg::PlayerStatus(ps) => {
            tracing::info!(state = ps.state.as_str(), place_id = ?ps.place_id, "player status");
        }
        Msg::FilesComplete(fc) => {
            let mut guard = state.lock().await;
            guard.handle_files_complete(&fc.execution_id);
        }
        Msg::SessionExited(e) => {
            // Session-level death event. Per-VM run cleanup is handled
            // separately by `Msg::VmDisconnect` (the OS closes the plugin's
            // socket when the process dies, the WS reader fires VmDisconnect,
            // master's existing handler orphans active_runs as KILLED). This
            // handler does only what's session-level: drop session_meta /
            // studio_instances, fire Error on any open launch stream for
            // this session, run reconcile() to drain pending_runs scoped to
            // the dead session.
            let session_guid = e.session_guid.clone();
            let reason = e.reason.clone();
            tracing::info!(session_guid = %session_guid, reason = %reason, "session exited");
            let mut guard = state.lock().await;
            guard.reconcile();
        }
        Msg::SaveResult(result) => {
            // Route the backend's typed reply to the awaiting save_place RPC
            // via its oneshot channel (keyed by request_id).
            let rid = result.request_id.clone();
            let mut guard = state.lock().await;
            if let Some(tx) = guard.pending_saves.remove(&rid) {
                let _ = tx.send(*result);
            } else {
                tracing::warn!(
                    request_id = &rid[..8.min(rid.len())],
                    "save: received SaveResult without a pending RPC (dropped)"
                );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// RunService
// ---------------------------------------------------------------------------

impl proto::RunService for RodeoServices {
    async fn run(
        &self,
        _ctx: Context,
        mut requests: Pin<Box<dyn Stream<Item = Result<OwnedView<proto::RunClientMessageView<'static>>, ConnectError>> + Send>>,
    ) -> Result<(Pin<Box<dyn Stream<Item = Result<proto::RunEvent, ConnectError>> + Send>>, Context), ConnectError> {
        let state = self.state.clone();

        // First message must be Submit
        let first = requests.next().await
            .ok_or_else(|| ConnectError::invalid_argument("expected SubmitRequest as first message"))?
            .map_err(|e| ConnectError::internal(format!("stream error: {e}")))?;

        let first_owned = first.to_owned_message();
        let submit = match first_owned.msg {
            Some(proto::run_client_message::Msg::Submit(s)) => s,
            _ => return Err(ConnectError::invalid_argument("first message must be SubmitRequest")),
        };

        let execution_id = submit.execution_id.clone();

        // Channel for events back to client
        let (event_tx, event_rx) = mpsc::unbounded_channel::<proto::RunEvent>();

        // client_tx bridges plugin output → RunEvent stream
        let (client_tx, mut client_rx) = mpsc::unbounded_channel::<crate::master::ClientMsg>();
        let evt_tx = event_tx.clone();
        tokio::spawn(async move {
            while let Some(msg) = client_rx.recv().await {
                match msg {
                    crate::master::ClientMsg::Disconnect(reason) => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::Disconnect(reason)),
                            ..Default::default()
                        });
                    }
                    crate::master::ClientMsg::FileChunk(chunk) => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::FileChunk(Box::new(chunk))),
                            ..Default::default()
                        });
                    }
                    crate::master::ClientMsg::Complete => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::Complete(Box::new(proto::RunComplete::default()))),
                            ..Default::default()
                        });
                    }
                    crate::master::ClientMsg::RpcCall(call) => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::RpcCall(call)),
                            ..Default::default()
                        });
                    }
                    crate::master::ClientMsg::ExecutionDone(done) => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::ExecutionDone(done)),
                            ..Default::default()
                        });
                    }
                    crate::master::ClientMsg::ExecutionKilled(killed) => {
                        let _ = evt_tx.send(proto::RunEvent {
                            event: Some(proto::run_event::Event::ExecutionKilled(killed)),
                            ..Default::default()
                        });
                    }
                }
            }
        });

        // Route the run
        let process_id = {
            let mut guard = state.lock().await;
            let pid = guard.next_pid();

            let run_request = crate::studio_backend::connection::RunRequest {
                execution_id: execution_id.clone(),
                script: submit.script,
                target: submit.target,
                session: submit.session,
                vm_id: submit.vm_id,
                job: submit.job,
                log_filter: submit.log_filter.into_option().unwrap_or_default(),
                cache_requires: submit.cache_requires,
                script_args: if submit.script_args.is_empty() { None } else { Some(submit.script_args) },
                return_file: submit.return_file,
                show_return: submit.show_return,
                output_file: submit.output_file,
                verbose: submit.verbose,
                instance_path: submit.instance_path,
                script_path: submit.script_path,
                process_name: submit.process_name,
                profile: submit.profile,
                client_tx,
                process_id: pid,
                state: proto::ProcessState::PROCESS_STATE_QUEUED,
                created_at: crate::util::time::now(),
            };

            let routed = guard.route_or_queue(run_request);
            if routed { tracing::info!(pid, "routed"); } else { tracing::info!(pid, "queued (no matching vm)"); }

            let _ = event_tx.send(proto::RunEvent {
                event: Some(proto::run_event::Event::Created(Box::new(proto::ProcessCreated {
                    process_id: pid,
                    execution_id: execution_id.clone(),
                    ..Default::default()
                }))),
                ..Default::default()
            });

            pid
        };

        // Spawn task to read client messages (typed RpcResponse + typed Kill).
        // These are both forwarded as-is to the plugin (server is a pure pipe).
        let client_state = state.clone();
        let eid = execution_id.clone();
        tokio::spawn(async move {
            while let Some(Ok(view)) = requests.next().await {
                let client_msg = view.to_owned_message();
                match client_msg.msg {
                    Some(proto::run_client_message::Msg::RpcResponse(resp)) => {
                        // Typed ClientRpcResponse → typed ServerMessage::RpcResponse.
                        // send_to_vm wraps in MasterMessage::VmServerMessage for the backend.
                        let plugin_msg = proto::ServerMessage {
                            msg: Some(proto::server_message::Msg::RpcResponse(resp)),
                            ..Default::default()
                        };
                        let guard = client_state.lock().await;
                        if let Some(run) = guard.active_runs.get(&eid) {
                            let vm_id = run.vm_id.clone();
                            guard.send_to_vm(&vm_id, plugin_msg);
                        }
                    }
                    Some(proto::run_client_message::Msg::Kill(kill)) => {
                        let plugin_msg = proto::ServerMessage {
                            msg: Some(proto::server_message::Msg::Kill(kill)),
                            ..Default::default()
                        };
                        let guard = client_state.lock().await;
                        if let Some(run) = guard.active_runs.get(&eid) {
                            let vm_id = run.vm_id.clone();
                            guard.send_to_vm(&vm_id, plugin_msg);
                        }
                    }
                    _ => {}
                }
            }

            // Client disconnected
            let mut guard = client_state.lock().await;
            guard.disconnect_run(process_id, &eid);
        });

        let output_stream = tokio_stream::wrappers::UnboundedReceiverStream::new(event_rx)
            .map(|msg| Ok(msg));

        Ok((Box::pin(output_stream), Context::default()))
    }
}

// ---------------------------------------------------------------------------
// MasterService — unary RPCs for all clients (gRPC + Connect plain JSON)
// ---------------------------------------------------------------------------

impl proto::MasterService for RodeoServices {
    async fn health(&self, _ctx: Context, _req: OwnedView<proto::HealthRequestView<'static>>) -> Result<(proto::HealthResponse, Context), ConnectError> {
        let guard = self.state.lock().await;
        let all = guard.all_vms();
        let vms: Vec<proto::VmInfo> = all.iter().map(|(vm_id, vm)| proto::VmInfo {
            rodeo_id: vm_id.clone(),
            active_count: vm.active_runs,
            is_idle: vm.connected && vm.active_runs == 0,
            ..Default::default()
        }).collect();
        let total_vms = vms.len() as u32;
        let total_queued = guard.pending_runs.len() as u32;
        Ok((proto::HealthResponse {
            launched: !guard.backends.is_empty(),
            context_count: 0,
            total_vms,
            total_queued,
            contexts: vec![proto::ContextInfo {
                bitset: 0,
                vm_count: total_vms,
                total_queued,
                vms,
                ..Default::default()
            }],
            ..Default::default()
        }, Context::default()))
    }

    async fn get_state(&self, _ctx: Context, _req: OwnedView<proto::GetStateRequestView<'static>>) -> Result<(proto::RodeoSnapshot, Context), ConnectError> {
        let guard = self.state.lock().await;
        Ok((guard.snapshot(), Context::default()))
    }

    async fn list_processes(&self, _ctx: Context, _req: OwnedView<proto::ListProcessesRequestView<'static>>) -> Result<(proto::ProcessListResponse, Context), ConnectError> {
        let guard = self.state.lock().await;
        Ok((proto::ProcessListResponse {
            processes: guard.snapshot().processes,
            ..Default::default()
        }, Context::default()))
    }

    async fn kill_process(&self, _ctx: Context, req: OwnedView<proto::KillProcessRequestView<'static>>) -> Result<(proto::KillResponse, Context), ConnectError> {
        let pid = req.process_id;
        let guard = self.state.lock().await;
        if let Some((eid, vm_id)) = guard.find_by_process_id(pid) {
            let eid_owned = eid.to_string();
            let vm_id_owned = vm_id.to_string();
            tracing::info!(pid, execution_id = eid_owned.as_str(), vm = &vm_id_owned[..8.min(vm_id_owned.len())], "kill: dispatching to vm");
            let kill_msg = proto::ServerMessage {
                msg: Some(proto::server_message::Msg::Kill(Box::new(proto::KillCommand {
                    execution_id: eid_owned.clone(),
                    ..Default::default()
                }))),
                ..Default::default()
            };
            guard.send_to_vm(&vm_id_owned, kill_msg);
            Ok((proto::KillResponse { killed: true, process_id: pid, ..Default::default() }, Context::default()))
        } else {
            tracing::warn!(pid, "kill: process not found");
            Err(ConnectError::not_found(format!("process {pid} not found")))
        }
    }

    async fn launch_studio(&self, _ctx: Context, req: OwnedView<proto::LaunchStudioRequestView<'static>>) -> Result<(Pin<Box<dyn Stream<Item = Result<proto::LaunchStudioEvent, ConnectError>> + Send>>, Context), ConnectError> {
        let backend_name = req.backend.to_string();
        let guard = self.state.lock().await;
        let backend = guard.backends.values()
            .find(|b| b.kind == "studio" && (b.id.starts_with(&backend_name) || b.name == backend_name));
        let Some(b) = backend else {
            return Err(ConnectError::not_found(format!("studio backend '{}' not found", backend_name)));
        };

        let backend_id = b.id.clone();
        let studio_id = uuid::Uuid::new_v4().to_string();
        let mut state_rx = b.state_rx.clone();

        let _ = b.tx.send(proto::MasterMessage {
            msg: Some(proto::master_message::Msg::LaunchStudio(Box::new(proto::LaunchStudioCommand {
                session_guid: studio_id.clone(),
                place_file: req.place_file.map(|s| s.to_string()),
                place_id: req.place_id,
                fflags: req.fflags.iter().map(|s| s.to_string()).collect(),
                background: req.background,
                detached: req.detached,
                no_hud: req.no_hud,
                profile: req.profile,
                save_path: req.save_path.map(|s| s.to_string()),
                fflag_file: req.fflag_file.map(|s| s.to_string()),
                ..Default::default()
            }))),
            ..Default::default()
        });
        drop(guard);

        let (tx, rx) = mpsc::unbounded_channel();

        let _ = tx.send(proto::LaunchStudioEvent {
            event: Some(proto::launch_studio_event::Event::Launching(Box::new(proto::StudioLaunching::default()))),
            ..Default::default()
        });

        // Watch backend state for studio_id to reach "connected" or "error".
        // The backend's monitor converts early process-exit into a status=error
        // before removing the instance (see studio_backend/backend.rs monitor
        // loop), so the caller gets a clear failure rather than a silent hang
        // when Studio crashes during plugin load.
        tokio::spawn(async move {
            while state_rx.changed().await.is_ok() {
                let snap = state_rx.borrow();
                if let Some(inst) = snap.studio_instances.iter().find(|i| i.session_guid == studio_id) {
                    match inst.status.as_str() {
                        "connected" => {
                            let _ = tx.send(proto::LaunchStudioEvent {
                                event: Some(proto::launch_studio_event::Event::Ready(Box::new(proto::StudioReady {
                                    backend_id: backend_id.clone(),
                                    session_guid: studio_id.clone(),
                                    ..Default::default()
                                }))),
                                ..Default::default()
                            });
                            break;
                        }
                        "error" => {
                            let _ = tx.send(proto::LaunchStudioEvent {
                                event: Some(proto::launch_studio_event::Event::Error(Box::new(proto::StudioLaunchError {
                                    message: inst.error.clone().unwrap_or_default(),
                                    ..Default::default()
                                }))),
                                ..Default::default()
                            });
                            break;
                        }
                        _ => {} // "launching" — keep waiting
                    }
                }
            }
        });

        let stream = tokio_stream::wrappers::UnboundedReceiverStream::new(rx).map(Ok);
        Ok((Box::pin(stream), Context::default()))
    }

    async fn set_studio_mode(&self, _ctx: Context, req: OwnedView<proto::SetStudioModeRequestView<'static>>) -> Result<(proto::SetStudioModeResponse, Context), ConnectError> {
        let session_guid = req.session_guid.to_string();
        let mode = req.mode.to_string();

        if mode.is_empty() {
            // Query only — check backend snapshot for this session's mode
            let guard = self.state.lock().await;
            let current_mode = guard.mode_for_session(&session_guid).unwrap_or_else(|| "edit".to_string());
            return Ok((proto::SetStudioModeResponse { ok: true, mode: current_mode, ..Default::default() }, Context::default()));
        }

        // Validate mode
        match mode.as_str() {
            "edit" | "run" | "play" | "test" => {}
            _ => return Err(ConnectError::invalid_argument(format!("unknown mode '{}'", mode))),
        }

        // Write target_modes and push SetTargetModeMsg to the edit VM — plugin drives the transition.
        let mut guard = self.state.lock().await;
        guard.set_target_mode(&session_guid, &mode);
        drop(guard);

        Ok((proto::SetStudioModeResponse { ok: true, mode, ..Default::default() }, Context::default()))
    }

    async fn close_studio(&self, _ctx: Context, req: OwnedView<proto::CloseStudioRequestView<'static>>) -> Result<(Pin<Box<dyn Stream<Item = Result<proto::CloseStudioEvent, ConnectError>> + Send>>, Context), ConnectError> {
        let session_guid = req.session_guid.to_string();
        let guard = self.state.lock().await;
        let studio_backend = guard.backends.values().find(|b| b.kind == "studio");
        let Some(b) = studio_backend else {
            return Err(ConnectError::not_found("no studio backend connected"));
        };

        let mut state_rx = b.state_rx.clone();
        let _ = b.tx.send(proto::MasterMessage {
            msg: Some(proto::master_message::Msg::CloseStudio(Box::new(proto::CloseStudioCommand {
                session_guid: session_guid.clone(),
                ..Default::default()
            }))),
            ..Default::default()
        });
        drop(guard);

        let (tx, rx) = mpsc::unbounded_channel();

        let _ = tx.send(proto::CloseStudioEvent {
            event: Some(proto::close_studio_event::Event::Closing(Box::new(proto::StudioClosing::default()))),
            ..Default::default()
        });

        // Watch backend state for session_guid to disappear from studio_instances
        tokio::spawn(async move {
            while state_rx.changed().await.is_ok() {
                let snap = state_rx.borrow();
                if !snap.studio_instances.iter().any(|i| i.session_guid == session_guid) {
                    let _ = tx.send(proto::CloseStudioEvent {
                        event: Some(proto::close_studio_event::Event::Closed(Box::new(proto::StudioClosed::default()))),
                        ..Default::default()
                    });
                    break;
                }
            }
        });

        let stream = tokio_stream::wrappers::UnboundedReceiverStream::new(rx).map(Ok);
        Ok((Box::pin(stream), Context::default()))
    }

    async fn save_place(&self, _ctx: Context, req: OwnedView<proto::SavePlaceRequestView<'static>>) -> Result<(proto::SavePlaceResponse, Context), ConnectError> {
        // Typed SaveCommand → await SaveResult reply. Routing key is a per-RPC
        // UUID (request_id), not session_guid: session_guid is optional payload
        // (backend falls back to the only connected Studio if caller didn't
        // specify). Using request_id keeps routing independent of payload.
        let request_id = uuid::Uuid::new_v4().to_string();
        let session_guid = req.session_guid.map(|s| s.to_string()).filter(|s| !s.is_empty());

        let (tx, rx) = tokio::sync::oneshot::channel();
        {
            let mut guard = self.state.lock().await;
            // Register reply channel BEFORE sending — guaranteed to route
            // whatever the backend sends back.
            guard.pending_saves.insert(request_id.clone(), tx);
            let Some(backend) = guard.backends.values().find(|b| b.kind == "studio") else {
                guard.pending_saves.remove(&request_id);
                return Err(ConnectError::not_found("no Studio backend registered"));
            };
            let send = backend.tx.send(proto::MasterMessage {
                msg: Some(proto::master_message::Msg::Save(Box::new(proto::SaveCommand {
                    request_id: request_id.clone(),
                    session_guid,
                    ..Default::default()
                }))),
                ..Default::default()
            });
            if let Err(e) = send {
                guard.pending_saves.remove(&request_id);
                return Err(ConnectError::internal(format!(
                    "save: failed to queue SaveCommand to backend: {e}",
                )));
            }
        }

        // Backend's save confirm loop runs up to 60s (mtime watch + retries);
        // wait a bit longer so a slow-but-successful save isn't reported as
        // a deadline error here.
        match tokio::time::timeout(std::time::Duration::from_secs(70), rx).await {
            Ok(Ok(result)) => Ok((
                proto::SavePlaceResponse {
                    saved: result.saved,
                    path: result.path,
                    error: result.error,
                    ..Default::default()
                },
                Context::default(),
            )),
            Ok(Err(_)) => {
                let mut guard = self.state.lock().await;
                guard.pending_saves.remove(&request_id);
                Err(ConnectError::internal("save: backend dropped reply channel"))
            }
            Err(_) => {
                let mut guard = self.state.lock().await;
                guard.pending_saves.remove(&request_id);
                Err(ConnectError::deadline_exceeded(
                    "save: no SaveResult from backend within 70s",
                ))
            }
        }
    }

    async fn list_backends(&self, _ctx: Context, req: OwnedView<proto::ListBackendsRequestView<'static>>) -> Result<(proto::ListBackendsResponse, Context), ConnectError> {
        let kind_filter = req.kind.map(|s| s.to_string());
        let guard = self.state.lock().await;
        let backends = guard.backends.values()
            .filter(|b| kind_filter.as_ref().map_or(true, |k| k.is_empty() || b.kind == *k))
            .map(|b| proto::BackendInfo {
                id: b.id.clone(),
                kind: b.kind.clone(),
                name: b.name.clone(),
                ..Default::default()
            })
            .collect();
        Ok((proto::ListBackendsResponse { backends, ..Default::default() }, Context::default()))
    }
}

// ---------------------------------------------------------------------------
// LiveBackendService removed — reserved for the live-runtime work.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

/// Build a ConnectRPC router: gRPC + Connect (plain JSON) + gRPC-Web on one port.
pub fn build_router(state: SharedMasterState) -> connectrpc::Router {
    use proto::{BackendServiceExt, RunServiceExt, MasterServiceExt};

    let svc = Arc::new(RodeoServices { state });

    let router = <RodeoServices as BackendServiceExt>::register(svc.clone(), connectrpc::Router::new());
    let router = <RodeoServices as RunServiceExt>::register(svc.clone(), router);
    let router = <RodeoServices as MasterServiceExt>::register(svc, router);

    router
}

/// Helper: convert ProcessState to human-readable string (can't impl Display on foreign type).
pub fn process_state_str(state: &proto::ProcessState) -> &'static str {
    match state {
        proto::ProcessState::PROCESS_STATE_QUEUED => "queued",
        proto::ProcessState::PROCESS_STATE_RUNNING => "running",
        proto::ProcessState::PROCESS_STATE_DONE => "done",
        proto::ProcessState::PROCESS_STATE_ERROR => "error",
        proto::ProcessState::PROCESS_STATE_KILLED => "killed",
        proto::ProcessState::PROCESS_STATE_DISCONNECTED => "disconnected",
    }
}
