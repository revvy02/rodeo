//! Studio backend mode: connects to master via connectrpc gRPC.
//!
//! Uses connectrpc-generated client stubs for typed RPC. Plugin VMs are uplifted
//! to master via the Control bidirectional stream. File transfers (profile dumps)
//! use the SendFile client streaming RPC.

use anyhow::{Context, Result};
use rodeo_proto as proto;
use crate::master::SharedBackendState;
use std::sync::Arc;
use tokio::sync::mpsc;
use tracing::info;

/// Connect to master via connectrpc gRPC and register as a studio backend.
/// Returns (client, backend_id, master_id, bidi_stream) for the Control RPC.
/// `master_id` is master's bootstrap UUID — empty string if master is too old
/// to advertise it.
pub async fn connect_to_master(
    master_host: &str,
    master_port: u16,
    local_port: Option<u16>,
) -> Result<(
    proto::BackendServiceClient<connectrpc::client::HttpClient>,
    String,
    String,
    connectrpc::client::BidiStream<hyper::body::Incoming, proto::BackendMessage, proto::MasterMessageView<'static>>,
)> {
    let url = format!("http://{master_host}:{}", master_port);
    info!(url = url.as_str(), "connecting to master via connectrpc");

    let http = connectrpc::client::HttpClient::plaintext();
    let config = connectrpc::client::ClientConfig::new(url.parse().context("invalid master URL")?);
    let client = proto::BackendServiceClient::new(http, config);

    let hostname = hostname::get()
        .map(|h| h.to_string_lossy().to_string())
        .unwrap_or_else(|_| "unknown".to_string());

    // Open Control bidi stream
    let mut bidi = client.control().await
        .map_err(|e| anyhow::anyhow!("control stream failed: {e}"))?;

    // Send Register as first message
    bidi.send(proto::BackendMessage {
        msg: Some(proto::backend_message::Msg::Register(Box::new(proto::RegisterRequest {
            kind: "studio".to_string(),
            name: hostname,
            port: local_port.map(|p| p as u32),
            ..Default::default()
        }))),
        ..Default::default()
    }).await.map_err(|e| anyhow::anyhow!("failed to send register: {e}"))?;

    // Read RegisterResponse (first MasterMessage)
    let first = bidi.message().await
        .map_err(|e| anyhow::anyhow!("expected RegisterResponse: {e}"))?
        .ok_or_else(|| anyhow::anyhow!("stream closed before RegisterResponse"))?;
    let first_owned = first.to_owned_message();
    let (backend_id, master_id) = match first_owned.msg {
        Some(proto::master_message::Msg::Registered(r)) => (r.id, r.master_id),
        _ => anyhow::bail!("expected RegisterResponse as first message"),
    };

    info!(
        backend_id = &backend_id[..8.min(backend_id.len())],
        master_id = &master_id[..8.min(master_id.len())],
        "registered with master",
    );

    Ok((client, backend_id, master_id, bidi))
}

/// Run the master connection loop via connectrpc Control bidi stream.
pub async fn run_master_loop(
    client: proto::BackendServiceClient<connectrpc::client::HttpClient>,
    _backend_id: String,
    mut bidi: connectrpc::client::BidiStream<hyper::body::Incoming, proto::BackendMessage, proto::MasterMessageView<'static>>,
    state: SharedBackendState,
) {
    // Relay channel: plugin_ws sends proto::BackendMessage, forwarded to bidi stream
    let (relay_tx, mut relay_rx) = mpsc::unbounded_channel::<proto::BackendMessage>();

    // Log dump channel: plugin_ws relay path sends LogDumpTask here for processing
    let (log_dump_tx, mut log_dump_rx) = mpsc::unbounded_channel::<crate::master::LogDumpTask>();

    // Spawn task to forward relay messages to bidi stream
    let (outgoing_tx, mut outgoing_rx) = mpsc::unbounded_channel::<proto::BackendMessage>();
    let relay_out_tx = outgoing_tx.clone();
    tokio::spawn(async move {
        while let Some(msg) = relay_rx.recv().await {
            if relay_out_tx.send(msg).is_err() { break; }
        }
    });

    {
        let mut guard = state.lock().await;
        guard.relay_tx = Some(relay_tx.clone());
        guard.log_dump_tx = Some(log_dump_tx);
    }

    // Send vm_connect for already-connected VMs
    {
        let guard = state.lock().await;
        for (vm_id, vm) in &guard.vms {
            if vm.connected {
                let state_json = serde_json::to_string(&vm.state).unwrap_or_default();
                let _ = bidi.send(proto::BackendMessage {
                    msg: Some(proto::backend_message::Msg::VmConnect(Box::new(proto::VmConnect {
                        vm_id: vm_id.clone(), state_json,
                        ..Default::default()
                    }))),
                    ..Default::default()
                }).await;
            }
        }
    }

    // State snapshots: periodic (2s) + event-driven via snapshot_trigger
    {
        let snapshot_state = state.clone();
        let snapshot_tx = outgoing_tx.clone();
        let trigger = Arc::new(tokio::sync::Notify::new());
        {
            let mut guard = state.lock().await;
            guard.snapshot_trigger = Some(trigger.clone());
        }
        tokio::spawn(async move {
            loop {
                tokio::select! {
                    _ = tokio::time::sleep(std::time::Duration::from_secs(2)) => {}
                    _ = trigger.notified() => {}
                }
                let snapshot = build_state_snapshot(&snapshot_state).await;
                let msg = proto::BackendMessage {
                    msg: Some(proto::backend_message::Msg::StateSnapshot(Box::new(snapshot))),
                    ..Default::default()
                };
                if snapshot_tx.send(msg).is_err() { break; }
            }
        });
    }

    // Spawn task to send outgoing messages on bidi stream
    // We need a separate task because bidi.send() requires &mut bidi
    // but we also need to receive from bidi concurrently.
    // Use a channel-based approach instead.
    let loop_state = state.clone();

    loop {
        tokio::select! {
            // Forward outgoing messages to bidi stream
            msg = outgoing_rx.recv() => {
                match msg {
                    Some(m) => {
                        if bidi.send(m).await.is_err() { break; }
                    }
                    None => break,
                }
            }
            // Receive incoming master messages
            result = bidi.message() => {
                match result {
                    Ok(Some(view)) => {
                        let master_msg = view.to_owned_message();
                        if let Some(msg) = master_msg.msg {
                            handle_master_msg(msg, &client, &outgoing_tx, &loop_state).await;
                        }
                    }
                    _ => break,
                }
            }
            // Log dump tasks from plugin_ws relay path
            task = log_dump_rx.recv() => {
                if let Some(task) = task {
                    let dump_client = client.clone();
                    let files_done_tx = outgoing_tx.clone();
                    tokio::spawn(async move {
                        // Empty PathBuf is the "logs=true but unresolved" sentinel —
                        // skip the read; still emit FilesComplete below so master
                        // stops waiting for this run's files.
                        if task.log_path.as_os_str().is_empty() {
                            tracing::debug!(execution_id = task.execution_id.as_str(), "log dump: skipping read (unresolved path), emitting FilesComplete only");
                        } else {
                            // Blocking file read on the blocking pool so a slow disk
                            // or large log doesn't stall async worker threads.
                            let log_path = task.log_path.clone();
                            let start_offset = task.start_offset;
                            let read_result = tokio::task::spawn_blocking(move || {
                                use std::io::{Read, Seek, SeekFrom};
                                let mut f = std::fs::File::open(&log_path)?;
                                f.seek(SeekFrom::Start(start_offset))?;
                                let mut buf = Vec::new();
                                f.read_to_end(&mut buf)?;
                                std::io::Result::Ok(buf)
                            }).await;

                            let result: std::io::Result<Vec<u8>> = match read_result {
                                Ok(r) => r,
                                Err(join_err) => Err(std::io::Error::new(std::io::ErrorKind::Other, format!("spawn_blocking join: {join_err}"))),
                            };

                            match result {
                                Ok(data) => {
                                    // Flat, self-describing filename:
                                    //   exec-<execution_id>-<session_guid>-<ts>.log
                                    // execution_id alone is globally unique; session_guid
                                    // enables `ls | grep <session_guid>` to collect every
                                    // dump from one Studio; ts orders chronologically.
                                    let ts = crate::util::log_capture::filename_timestamp();
                                    let filename = if task.session_guid.is_empty() {
                                        format!("exec-{}-{}.log", &task.execution_id, ts)
                                    } else {
                                        format!("exec-{}-{}-{}.log", &task.execution_id, &task.session_guid, ts)
                                    };
                                    let chunks = stream_file_chunks(&filename, &task.execution_id, &data);
                                    if let Err(e) = dump_client.send_file(chunks).await {
                                        tracing::warn!("log dump send failed: {e}");
                                    } else {
                                        tracing::debug!(filename, size = data.len(), "log dump: sent via gRPC");
                                    }
                                }
                                Err(e) => tracing::warn!(execution_id = task.execution_id.as_str(), "log dump read failed: {e}"),
                            }
                        }
                        // Signal master that file transfer is complete
                        let _ = files_done_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::FilesComplete(Box::new(proto::FilesComplete {
                                execution_id: task.execution_id,
                                ..Default::default()
                            }))),
                            ..Default::default()
                        });
                    });
                }
            }
        }
    }

    { let mut guard = state.lock().await; guard.relay_tx = None; }
    info!("master connection closed");
}

async fn handle_master_msg(
    msg: proto::master_message::Msg,
    client: &proto::BackendServiceClient<connectrpc::client::HttpClient>,
    outgoing_tx: &mpsc::UnboundedSender<proto::BackendMessage>,
    state: &SharedBackendState,
) {
    match msg {
        proto::master_message::Msg::VmServerMessage(vm_server) => {
            let vm_id = vm_server.vm_id.clone();
            let server_msg = match vm_server.message.into_option() {
                Some(m) => m,
                None => return,
            };

            // If profiled or logged run, wire up file collection.
            // Match directly on the typed oneof — no JSON parsing.
            if let Some(proto::server_message::Msg::Run(ref run_cmd)) = server_msg.msg {
                let execution_id = run_cmd.execution_id.clone();

                // Profile dumps: register scanner and stream via gRPC.
                // Scanner is keyed by execution_id (label embedded in dump file).
                if run_cmd.profile == Some(true) {
                    let guard = state.lock().await;
                    let session_guid = guard.vms.get(&vm_id)
                        .and_then(|vm| vm.session_guid.clone())
                        .unwrap_or_default();
                    if let Some(ref scanner) = guard.profile_scanner {
                        let mut dump_rx = scanner.register(execution_id.clone());
                        let eid = execution_id.clone();
                        let sg = session_guid.clone();
                        let dump_client = client.clone();
                        let files_done_tx = outgoing_tx.clone();
                        tokio::spawn(async move {
                            while let Some(dump) = dump_rx.recv().await {
                                // Flat, self-describing filename:
                                //   profile-<execution_id>-<session_guid>-<ts>-<raw>
                                // raw carries the scanner's original name (which includes
                                // its own sequence / sample marker).
                                let ts = crate::util::log_capture::filename_timestamp();
                                let filename = if sg.is_empty() {
                                    format!("profile-{}-{}-{}", &eid, ts, &dump.filename)
                                } else {
                                    format!("profile-{}-{}-{}-{}", &eid, &sg, ts, &dump.filename)
                                };
                                let chunks = stream_file_chunks(&filename, &eid, &dump.data);
                                if let Err(e) = dump_client.send_file(chunks).await {
                                    tracing::warn!("profile send failed: {e}");
                                } else {
                                    tracing::debug!(filename = filename.as_str(), size = dump.data.len(), "profile: sent via gRPC");
                                }
                            }
                            // Scanner unregistered, dump_rx closed — all files sent
                            let _ = files_done_tx.send(proto::BackendMessage {
                                msg: Some(proto::backend_message::Msg::FilesComplete(Box::new(proto::FilesComplete {
                                    execution_id: eid,
                                    ..Default::default()
                                }))),
                                ..Default::default()
                            });
                        });
                        tracing::debug!(execution_id, "profile: registered run on backend scanner");
                    }
                    drop(guard);
                }

                // Log dump: record the target Studio's log file + current byte offset.
                // Keyed by execution_id. The log file is resolved via the scanner
                // at Studio launch time; we look it up through the target VM's
                // session_guid → studio_instances → studio.log_path().
                //
                // IMPORTANT: master's complete_run holds the run open waiting for
                // FilesComplete whenever logs=true (see mod.rs:1156). So we must
                // ALWAYS populate log_runs for logs=true runs, even when we can't
                // resolve the log path — otherwise the plugin_ws Done handler
                // doesn't fire a LogDumpTask and master hangs forever. An empty
                // PathBuf sentinel signals "logs=true but no path" to the dump
                // task, which skips the file read and goes straight to
                // FilesComplete.
                if run_cmd.logs == Some(true) {
                    let log_path = {
                        let guard = state.lock().await;
                        let Some(vm) = guard.vms.get(&vm_id) else { return };
                        let connected_at = vm.connected_at;
                        let dom = vm.state.as_ref().map(|s| s.dom.as_str()).unwrap_or("");
                        let sid = vm.session_guid.clone();
                        sid.and_then(|sid| {
                            // Edit-Studio path: 1 process per session.
                            if let Some(p) = guard.studio_instances.get(&sid)
                                .and_then(|inst| inst.studio.as_ref())
                                .and_then(|s| s.log_path())
                            { return Some(p); }

                            // MP-test path: 1 server + N clients share session_guid.
                            // Pair the VM with the matching process by spawn-vs-connect
                            // time ordering (the most-recently-launched process whose
                            // launched_at precedes this VM's connect is its owner).
                            let session = guard.multiplayer_test_sessions.get(&sid)?;
                            if dom == "client" {
                                session.clients().values()
                                    .filter(|c| c.launched_at() <= connected_at)
                                    .max_by_key(|c| c.launched_at())
                                    .and_then(|c| c.log_path())
                            } else {
                                session.log_path()
                            }
                        })
                    };
                    let (path_to_store, offset) = match log_path {
                        Some(p) => {
                            let off = std::fs::metadata(&p).map(|m| m.len()).unwrap_or(0);
                            tracing::debug!(execution_id, path = %p.display(), offset = off, "log dump: recorded start");
                            (p, off)
                        }
                        None => {
                            tracing::debug!(execution_id, vm_id = &vm_id[..8.min(vm_id.len())], "log dump: path unresolved (will emit empty FilesComplete)");
                            (std::path::PathBuf::new(), 0)
                        }
                    };
                    let mut guard = state.lock().await;
                    guard.log_runs.insert(execution_id.clone(), (path_to_store, offset));
                }
            }

            // Serialize the typed ServerMessage once and forward to the VM's plugin
            // over the WebSocket (which still speaks JSON-encoded proto).
            let kind = match &server_msg.msg {
                Some(proto::server_message::Msg::Welcome(_)) => "welcome",
                Some(proto::server_message::Msg::Run(_)) => "run",
                Some(proto::server_message::Msg::Kill(_)) => "kill",
                Some(proto::server_message::Msg::RpcResponse(_)) => "rpc_response",
                Some(proto::server_message::Msg::SetTargetMode(_)) => "set_target_mode",
                None => "empty",
            };
            let vm_short = &vm_id[..8.min(vm_id.len())];
            let json = serde_json::to_string(&server_msg).unwrap();
            let guard = state.lock().await;
            if let Some(vm_conn) = guard.vms.get(&vm_id) {
                match vm_conn.studio_tx.send(json) {
                    Ok(_) => tracing::debug!(vm = vm_short, kind, "backend → plugin: forwarded"),
                    Err(e) => tracing::warn!(vm = vm_short, kind, "backend → plugin: channel closed: {e}"),
                }
            } else {
                tracing::warn!(vm = vm_short, kind, "backend → plugin: vm not found in backend state");
            }
        }
        proto::master_message::Msg::Save(cmd) => {
            // Resolve which Studio to save, then fire Cmd+S + wait for mtime
            // + reply with SaveResult. Routing key is request_id; session_guid
            // is payload (may be absent — fall back to the only connected
            // Studio when there's exactly one; error otherwise).
            let request_id = cmd.request_id.clone();
            let caller_sg = cmd.session_guid.clone();
            let resolution = {
                let guard = state.lock().await;
                match caller_sg.as_deref().filter(|s| !s.is_empty()) {
                    Some(sg) => {
                        match guard.studio_instances.get(sg)
                            .filter(|inst| inst.status == "connected")
                            .and_then(|inst| inst.studio.clone())
                        {
                            Some(studio) => Ok((sg.to_string(), studio)),
                            None => Err(format!("no connected Studio for session_guid={sg}")),
                        }
                    }
                    None => {
                        // Fallback: only connected Studio wins.
                        let connected: Vec<_> = guard.studio_instances.iter()
                            .filter(|(_, inst)| inst.status == "connected")
                            .filter_map(|(sg, inst)| inst.studio.as_ref().map(|s| (sg.clone(), s.clone())))
                            .collect();
                        match connected.len() {
                            1 => Ok(connected.into_iter().next().unwrap()),
                            0 => Err("no connected Studio".to_string()),
                            n => Err(format!(
                                "{n} connected Studios; specify session_guid to disambiguate"
                            )),
                        }
                    }
                }
            };

            let outgoing = outgoing_tx.clone();
            let request_id_for_err = request_id.clone();
            let (session_guid, studio) = match resolution {
                Ok(r) => r,
                Err(err) => {
                    tracing::warn!("save: {err}");
                    let _ = outgoing.send(proto::BackendMessage {
                        msg: Some(proto::backend_message::Msg::SaveResult(Box::new(proto::SaveResult {
                            request_id: request_id_for_err,
                            session_guid: caller_sg,
                            saved: false,
                            path: None,
                            error: Some(err),
                            ..Default::default()
                        }))),
                        ..Default::default()
                    });
                    return;
                }
            };
            let sg_short: String = session_guid[..8.min(session_guid.len())].to_string();

            tokio::spawn(async move {
                let place_path = studio.place_path().map(|p| p.to_path_buf());
                let mtime_before = place_path.as_ref()
                    .and_then(|p| std::fs::metadata(p).ok())
                    .and_then(|m| m.modified().ok());
                tracing::info!(
                    session_guid = sg_short.as_str(),
                    place = ?place_path.as_ref().map(|p| p.display().to_string()),
                    "save: triggering studio.save()"
                );
                let save_outcome = studio.save();
                let (saved, path, error) = match save_outcome {
                    Err(e) => {
                        tracing::error!(session_guid = sg_short.as_str(), "save: studio.save() failed: {e}");
                        (false, place_path.map(|p| p.to_string_lossy().into_owned()), Some(e.to_string()))
                    }
                    Ok(()) => match (place_path, mtime_before) {
                        (Some(path), Some(before)) => {
                            let deadline = std::time::Instant::now() + std::time::Duration::from_secs(30);
                            let mut changed = false;
                            let mut ticks = 0u32;
                            loop {
                                tokio::time::sleep(std::time::Duration::from_millis(200)).await;
                                ticks += 1;
                                if std::time::Instant::now() > deadline { break; }
                                if let Ok(meta) = std::fs::metadata(&path) {
                                    if let Ok(now) = meta.modified() {
                                        if now != before { changed = true; break; }
                                    }
                                }
                            }
                            if changed {
                                tracing::info!(session_guid = sg_short.as_str(), ticks, "save: mtime changed, success");
                                (true, Some(path.to_string_lossy().into_owned()), None)
                            } else {
                                tracing::warn!(session_guid = sg_short.as_str(), ticks, "save: timed out waiting for mtime change");
                                (false, Some(path.to_string_lossy().into_owned()), Some("mtime did not change within 30s".to_string()))
                            }
                        }
                        _ => (true, None, None),
                    },
                };
                let _ = outgoing.send(proto::BackendMessage {
                    msg: Some(proto::backend_message::Msg::SaveResult(Box::new(proto::SaveResult {
                        request_id,
                        session_guid: Some(session_guid),
                        saved,
                        path,
                        error,
                        ..Default::default()
                    }))),
                    ..Default::default()
                });
            });
        }
        proto::master_message::Msg::RunCompleted(rc) => {
            let execution_id = rc.execution_id.clone();
            let guard = state.lock().await;
            // Profile scanner: unregister by execution_id.
            if let Some(ref scanner) = guard.profile_scanner {
                scanner.unregister(&execution_id);
                tracing::debug!(execution_id, "backend: unregistered scanner on RunCompleted");
            }
        }
        proto::master_message::Msg::LaunchStudio(cmd) => {
            let cmd = *cmd;
            let ls = state.clone();
            let out_tx = outgoing_tx.clone();
            let session_guid = cmd.session_guid.clone();
            {
                let mut guard = ls.lock().await;
                guard.studio_instances.insert(session_guid.clone(), crate::master::StudioInstanceInfo {
                    session_guid: session_guid.clone(),
                    status: "pending".to_string(),
                    studio: None,
                    error: None,
                    mcp_studio_id: None,
                });
                if let Some(ref notify) = guard.snapshot_trigger {
                    notify.notify_one();
                }
            }
            let shutdown_token = {
                let guard = ls.lock().await;
                guard.shutdown_token.clone()
            };
            tokio::spawn(async move {
                use crate::studio_backend::{Studio, StudioOptions, FflagConfig, PlaceTarget};
                let target = if let Some(file) = cmd.place_file {
                    PlaceTarget::File(file)
                } else if cmd.place_id.unwrap_or(0) > 0 {
                    PlaceTarget::PlaceId { place_id: cmd.place_id.unwrap(), universe_id: None }
                } else {
                    PlaceTarget::Empty
                };
                let guard = ls.lock().await;
                let port = guard.port;
                drop(guard);
                let mut fflags = FflagConfig { overrides: cmd.fflags, file: cmd.fflag_file };
                if cmd.profile {
                    fflags = crate::studio_backend::launch::inject_profile_fflags(fflags);
                }
                let opts = StudioOptions {
                    port,
                    background: cmd.background,
                    save: crate::studio_backend::parse_save_mode(cmd.save_path),
                    fflags,
                    detached: cmd.detached,
                    no_hud: cmd.no_hud,
                    session_guid: session_guid.clone(),
                };
                // Transition pending → launching
                {
                    let mut guard = ls.lock().await;
                    if let Some(inst) = guard.studio_instances.get_mut(&session_guid) {
                        inst.status = "launching".to_string();
                    }
                    if let Some(ref notify) = guard.snapshot_trigger {
                        notify.notify_one();
                    }
                }
                let sg_short = &session_guid[..8.min(session_guid.len())];
                tracing::info!(session_guid = sg_short, "Launching Studio on port {port}...");

                // Side-channel: snapshot StudioMCP's Studio list before spawn so we can
                // identify the new mcp_studio_id by diffing after spawn. Skipped if MCP
                // isn't initialized — launch-order correlation remains as fallback.
                tracing::info!(session_guid = sg_short, "launch: taking pre-spawn MCP snapshot");
                let pre_ids: std::collections::HashSet<String> = {
                    let mcp_arc = { ls.lock().await.mcp.clone() };
                    let mut mcp_guard = mcp_arc.lock().await;
                    match mcp_guard.as_mut() {
                        Some(client) => match client.list_studios().await {
                            Ok(entries) => entries.into_iter().map(|e| e.mcp_studio_id).collect(),
                            Err(e) => {
                                tracing::debug!(error = %e, "list_roblox_studios pre-snapshot failed; side-channel disabled for this launch");
                                std::collections::HashSet::new()
                            }
                        },
                        None => std::collections::HashSet::new(),
                    }
                };
                tracing::info!(session_guid = sg_short, pre_count = pre_ids.len(), "launch: pre-spawn MCP snapshot done, entering spawn_blocking");

                // Phase 1: spawn Studio (blocking — daemon slot + process spawn)
                // Handle is available immediately after spawn, before login gate
                let spawn_result = tokio::task::spawn_blocking(move || Studio::spawn(target, opts)).await;
                tracing::info!(session_guid = sg_short, ok = spawn_result.is_ok(), "launch: spawn_blocking returned");
                let instance = match spawn_result {
                    Ok(Ok(inst)) => std::sync::Arc::new(inst),
                    Ok(Err(e)) => {
                        tracing::error!("Studio spawn failed: {e}");
                        // Pre-handoff failure: emit SessionExited so master can
                        // fire Error on the open launch_studio stream + clean
                        // session-level state. Don't rely on snapshot polling.
                        let _ = out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::SessionExited(
                                Box::new(proto::SessionExited {
                                    session_guid: session_guid.clone(),
                                    reason: format!("launch_failed: {e}"),
                                    ..Default::default()
                                })
                            )),
                            ..Default::default()
                        });
                        let mut guard = ls.lock().await;
                        guard.studio_instances.remove(&session_guid);
                        if let Some(ref notify) = guard.snapshot_trigger { notify.notify_one(); }
                        return;
                    }
                    Err(e) => {
                        tracing::error!("Studio spawn task failed: {e}");
                        let _ = out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::SessionExited(
                                Box::new(proto::SessionExited {
                                    session_guid: session_guid.clone(),
                                    reason: format!("launch_failed: {e}"),
                                    ..Default::default()
                                })
                            )),
                            ..Default::default()
                        });
                        let mut guard = ls.lock().await;
                        guard.studio_instances.remove(&session_guid);
                        if let Some(ref notify) = guard.snapshot_trigger { notify.notify_one(); }
                        return;
                    }
                };

                // Store handle IMMEDIATELY — SIGTERM cleanup can now kill Studio
                {
                    let mut guard = ls.lock().await;
                    if let Some(inst) = guard.studio_instances.get_mut(&session_guid) {
                        inst.studio = Some(instance.clone());
                    }
                }

                // Pair this Studio with its log file via the scanner, then
                // continuously mirror the log to <logs_dir>/studio-<sg>-<ts>.log
                // until the Studio process exits.
                {
                    let scanner = {
                        let guard = ls.lock().await;
                        guard.log_scanner.clone()
                    };
                    if let Some(scanner) = scanner {
                        let inst = instance.clone();
                        let process_log = instance.process_log().clone();
                        let session_guid_for_log = session_guid.clone();
                        // Default to the shared subprocess log dir when the caller
                        // didn't specify one, so Studio logs always land next to
                        // master/studio-backend/player-backend logs for unified
                        // post-mortem debugging.
                        let logs_dir = cmd.logs_dir
                            .clone()
                            .filter(|s| !s.is_empty())
                            .unwrap_or_else(|| ".rodeo/.temp/logs".to_string());
                        let shutdown_for_mirror = shutdown_token.clone();
                        tokio::spawn(async move {
                            let Some(path) = scanner
                                .claim_new_log(inst.launched_at(), std::time::Duration::from_secs(10))
                                .await
                            else {
                                tracing::warn!(session_guid = %session_guid_for_log, "log scanner: claim timed out");
                                return;
                            };
                            tracing::debug!(session_guid = %session_guid_for_log, path = %path.display(), "log scanner: claimed log");
                            process_log.set(path.clone());

                            let ts = crate::util::log_capture::filename_timestamp();
                            let filename = format!("studio-{}-{}.log", session_guid_for_log, ts);
                            let dst = std::path::PathBuf::from(&logs_dir).join(filename);
                            mirror_studio_log(path, dst, inst, session_guid_for_log, shutdown_for_mirror).await;
                        });
                    }
                }

                // Side-channel: poll list_roblox_studios for the new mcp_studio_id.
                // Runs in the background so it doesn't block wait_for_ready. First new
                // entry not already claimed by another studio_instance is attributed
                // here. Timeout after 30s; launch-order correlation remains as fallback.
                {
                    let poll_state = ls.clone();
                    let poll_session_guid = session_guid.clone();
                    tokio::spawn(async move {
                        let start = std::time::Instant::now();
                        let timeout = std::time::Duration::from_secs(30);
                        let interval = std::time::Duration::from_millis(200);
                        loop {
                            tokio::time::sleep(interval).await;
                            if start.elapsed() > timeout {
                                tracing::debug!(session_guid = %poll_session_guid, "mcp_studio_id side-channel timed out");
                                return;
                            }
                            let mcp_arc = { poll_state.lock().await.mcp.clone() };
                            let entries_opt = {
                                let mut mcp_guard = mcp_arc.lock().await;
                                match mcp_guard.as_mut() {
                                    Some(client) => client.list_studios().await.ok(),
                                    None => None,
                                }
                            };
                            let Some(entries) = entries_opt else { continue };
                            let mut guard = poll_state.lock().await;
                            // Already claimed? (e.g. a reconnect raced us)
                            if guard.studio_instances.get(&poll_session_guid).and_then(|i| i.mcp_studio_id.clone()).is_some() {
                                return;
                            }
                            let claimed: std::collections::HashSet<String> = guard.studio_instances.values()
                                .filter_map(|i| i.mcp_studio_id.clone())
                                .collect();
                            let picked = entries.into_iter()
                                .find(|e| !pre_ids.contains(&e.mcp_studio_id) && !claimed.contains(&e.mcp_studio_id));
                            let Some(entry) = picked else { continue };
                            if let Some(inst) = guard.studio_instances.get_mut(&poll_session_guid) {
                                tracing::info!(session_guid = %poll_session_guid, mcp_studio_id = %entry.mcp_studio_id, "paired session with mcp_studio_id via side-channel");
                                inst.mcp_studio_id = Some(entry.mcp_studio_id);
                                if let Some(ref notify) = guard.snapshot_trigger { notify.notify_one(); }
                            }
                            return;
                        }
                    });
                }

                // Phase 2: wait for login gate (blocking, but Studio is already tracked)
                tracing::info!(session_guid = sg_short, "launch: entering wait_for_ready");
                let wait_instance = instance.clone();
                tokio::task::spawn_blocking(move || wait_instance.wait_for_ready()).await.ok();
                tracing::info!(session_guid = sg_short, "launch: wait_for_ready returned");

                // Event-driven exit handler — replaces the old 2-second polling
                // monitor. `Child::on_exit` fires via OS-level wait/kqueue, so we
                // learn about death immediately. The callback synthesizes a
                // SessionExited message; master handles per-VM run cleanup via
                // the existing VmDisconnect path (the OS closes the plugin's
                // WebSocket when the process dies → WS reader fires VmDisconnect).
                let exit_state = ls.clone();
                let exit_session_guid = session_guid.clone();
                let exit_out_tx = out_tx.clone();
                let exit_instance = instance.clone();
                instance.on_exit(move |_status| {
                    // Determine reason: was status still "launching" when we died?
                    // (i.e. plugin never connected) — call it launch_failed so
                    // the master's launch_studio stream gets a meaningful Error.
                    let session_guid = exit_session_guid.clone();
                    let exit_state = exit_state.clone();
                    let exit_out_tx = exit_out_tx.clone();
                    let exit_instance = exit_instance.clone();
                    tokio::spawn(async move {
                        let was_launching = {
                            let guard = exit_state.lock().await;
                            guard.studio_instances.get(&session_guid)
                                .map(|i| i.status == "launching" || i.status == "pending")
                                .unwrap_or(false)
                        };
                        let reason = if was_launching {
                            "launch_failed: Studio process exited during launch".to_string()
                        } else {
                            "exited".to_string()
                        };
                        tracing::info!(session_guid = %session_guid, reason = %reason, "Studio process exited (on_exit)");
                        exit_instance.cleanup();
                        let _ = exit_out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::SessionExited(
                                Box::new(proto::SessionExited {
                                    session_guid: session_guid.clone(),
                                    reason: reason.clone(),
                                    ..Default::default()
                                })
                            )),
                            ..Default::default()
                        });
                        // Drive the lifecycle transition through the snapshot —
                        // this is the same surface plugin-connect mutates via
                        // try_claim_session_from_handshake. Removing the row
                        // would lose the terminal state and leave any
                        // launch_studio watcher hanging (Studio crashes during
                        // plugin load → no Ready, no Error, just absence).
                        let mut guard = exit_state.lock().await;
                        if let Some(inst) = guard.studio_instances.get_mut(&session_guid) {
                            inst.status = "error".to_string();
                            inst.error = Some(reason);
                        }
                        if let Some(ref notify) = guard.snapshot_trigger {
                            notify.notify_one();
                        }
                    });
                });
            });
        }
        proto::master_message::Msg::LaunchMultiplayerTestServer(cmd) => {
            let cmd = *cmd;
            let out_tx = outgoing_tx.clone();
            let ls = state.clone();
            let rodeo_port = {
                let guard = ls.lock().await;
                guard.port
            };
            tokio::spawn(async move {
                use crate::studio_backend::{MultiplayerTestServer, MultiplayerTestServerOptions, FflagConfig, PlaceTarget};
                let session_guid = cmd.session_guid.clone();

                // Resolve place target — if published, download + stage locally first.
                // Helper: emit SessionExited for any early-return failure path so master
                // fires Error on the open launch stream (otherwise the stream hangs).
                let send_launch_failed = |reason: String| {
                    let _ = out_tx.send(proto::BackendMessage {
                        msg: Some(proto::backend_message::Msg::SessionExited(
                            Box::new(proto::SessionExited {
                                session_guid: session_guid.clone(),
                                reason: format!("launch_failed: {reason}"),
                                ..Default::default()
                            })
                        )),
                        ..Default::default()
                    });
                };

                let place_target = if let Some(file) = cmd.place_file {
                    PlaceTarget::File(file)
                } else if cmd.place_id.unwrap_or(0) > 0 {
                    let place_id = cmd.place_id.unwrap();
                    tracing::info!(place_id, "downloading place for play server...");
                    match rbx_control::place::download_place(place_id).await {
                        Ok(content) => {
                            if let Err(e) = rbx_control::place::stage_server_place(&content) {
                                tracing::error!("failed to stage published place: {e}");
                                send_launch_failed(format!("stage_server_place failed: {e}"));
                                return;
                            }
                            PlaceTarget::Empty  // already staged; signal via Empty
                        }
                        Err(e) => {
                            tracing::error!(place_id, "failed to download place: {e}");
                            send_launch_failed(format!("download_place failed: {e}"));
                            return;
                        }
                    }
                } else {
                    PlaceTarget::Empty
                };

                // Fetch Roblox user_id (required for -task StartServer auth).
                let user_id = match crate::commands::run::get_roblox_user_id().await {
                    Ok(uid) => uid,
                    Err(e) => {
                        tracing::error!("failed to get Roblox user_id: {e}");
                        send_launch_failed(format!("get_roblox_user_id failed: {e}"));
                        return;
                    }
                };

                let mut fflags = FflagConfig { overrides: cmd.fflags, file: cmd.fflag_file };
                if cmd.profile {
                    fflags = crate::studio_backend::launch::inject_profile_fflags(fflags);
                }
                match MultiplayerTestServer::launch(MultiplayerTestServerOptions {
                    place: place_target,
                    rodeo_port,
                    raknet_port: 0,
                    fflags,
                    background: cmd.background,
                    user_id,
                    session_guid: session_guid.clone(),
                    no_hud: cmd.no_hud,
                }) {
                    Ok(server) => {
                        let pid = server.pid();
                        let raknet_port = server.raknet_port();
                        let raknet_session_guid = server.raknet_session_guid().to_string();
                        let play_test_guid = server.play_test_guid().to_string();
                        tracing::info!(pid, port = raknet_port, session_guid = %session_guid, "play server launched");

                        let (exit_tx, exit_rx) = tokio::sync::oneshot::channel();
                        server.on_exit(move |status| {
                            let _ = exit_tx.send(status);
                        });

                        let session_meta = crate::master::MultiplayerTestSessionMeta {
                            session_guid: session_guid.clone(),
                            server: crate::master::MultiplayerTestServerState {
                                pid,
                                raknet_port,
                                raknet_session_guid: raknet_session_guid.clone(),
                                play_test_guid: play_test_guid.clone(),
                            },
                            clients: std::collections::HashMap::new(),
                            no_hud: cmd.no_hud,
                        };

                        let launched_at = server.launched_at();
                        let process_log = server.process_log().clone();
                        let mut guard = ls.lock().await;
                        guard.multiplayer_test_sessions.insert(session_guid.clone(), server);
                        guard.multiplayer_test_session_meta.insert(session_guid.clone(), session_meta);
                        if let Some(ref scanner) = guard.log_scanner {
                            scanner.pair(launched_at, process_log);
                        }
                        drop(guard);

                        // Server-exit watcher, scoped to this session_guid.
                        let state_clone = ls.clone();
                        let out_tx_clone = out_tx.clone();
                        let sid_for_watcher = session_guid.clone();
                        tokio::spawn(async move {
                            let _ = exit_rx.await;
                            tracing::info!(pid, session_guid = %sid_for_watcher, "play server exited; tearing down session");
                            {
                                let mut guard = state_clone.lock().await;
                                guard.multiplayer_test_sessions.remove(&sid_for_watcher);          // Drop cascades: kills clients
                                guard.multiplayer_test_session_meta.remove(&sid_for_watcher);
                            }
                            let _ = out_tx_clone.send(proto::BackendMessage {
                                msg: Some(proto::backend_message::Msg::SessionExited(
                                    Box::new(proto::SessionExited {
                                        session_guid: sid_for_watcher,
                                        reason: "exited".to_string(),
                                        ..Default::default()
                                    })
                                )),
                                ..Default::default()
                            });
                        });

                        let _ = out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::MultiplayerTestServerReady(Box::new(proto::MultiplayerTestServerReady {
                                pid,
                                raknet_port: raknet_port as u32,
                                raknet_session_guid,
                                play_test_guid,
                                session_guid: session_guid.clone(),
                                ..Default::default()
                            }))),
                            ..Default::default()
                        });
                    }
                    Err(e) => {
                        // Pre-handoff failure (Studio crashed during stdout-parse, etc).
                        // Master needs to know so it can fire Error on the open
                        // launch_multiplayer_test_server stream — without this, the
                        // client sits on the stream until disconnect.
                        tracing::error!(session_guid = %session_guid, "failed to launch play server: {e}");
                        let _ = out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::SessionExited(
                                Box::new(proto::SessionExited {
                                    session_guid: session_guid.clone(),
                                    reason: format!("launch_failed: {e}"),
                                    ..Default::default()
                                })
                            )),
                            ..Default::default()
                        });
                    }
                }
            });
        }
        proto::master_message::Msg::LaunchMultiplayerTestClient(cmd) => {
            let cmd = *cmd;
            let out_tx = outgoing_tx.clone();
            let ls = state.clone();
            let rodeo_port = {
                let guard = ls.lock().await;
                guard.port
            };
            tokio::spawn(async move {
                use crate::studio_backend::{MultiplayerTestClient, MultiplayerTestClientOptions};
                let user_id = match crate::commands::run::get_roblox_user_id().await {
                    Ok(uid) => uid,
                    Err(e) => {
                        tracing::error!(index = cmd.index, "failed to get Roblox user_id: {e}");
                        return;
                    }
                };
                let _ = rodeo_port; // plugin already shared from the server; generic client doesn't need this
                match MultiplayerTestClient::launch(MultiplayerTestClientOptions {
                    raknet_port: cmd.server_port as u16,
                    server_pid: cmd.server_pid,
                    raknet_session_guid: cmd.raknet_session_guid,
                    play_test_guid: cmd.play_test_guid,
                    index: cmd.index,
                    background: true,
                    user_id,
                    detached: false,
                    no_hud: cmd.no_hud,
                }) {
                    Ok(client) => {
                        let pid = client.pid();
                        let launched_at = client.launched_at();
                        let process_log = client.process_log().clone();
                        let session_guid = cmd.session_guid.clone();
                        tracing::info!(pid, index = cmd.index, session_guid = %session_guid, "play client launched");
                        let mut guard = ls.lock().await;
                        // MultiplayerTestServer (in guard.multiplayer_test_sessions[sid]) owns its clients —
                        // dropping the session drops this client's handle via Rust
                        // ownership, which kills its Studio process.
                        if let Some(session) = guard.multiplayer_test_sessions.get_mut(&session_guid) {
                            session.add_client(cmd.index, client);
                            if let Some(meta) = guard.multiplayer_test_session_meta.get_mut(&session_guid) {
                                meta.clients.insert(cmd.index, crate::master::MultiplayerTestClientState { pid, index: cmd.index });
                            }
                        } else {
                            tracing::warn!(index = cmd.index, session_guid = %session_guid, "LaunchMultiplayerTestClient: unknown session; client will leak");
                        }
                        if let Some(ref scanner) = guard.log_scanner {
                            scanner.pair(launched_at, process_log);
                        }
                        drop(guard);
                        let _ = out_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::MultiplayerTestClientReady(Box::new(proto::MultiplayerTestClientReady {
                                pid, index: cmd.index, session_guid, ..Default::default()
                            }))),
                            ..Default::default()
                        });
                    }
                    Err(e) => tracing::error!(index = cmd.index, "failed to launch play client: {e}"),
                }
            });
        }
        proto::master_message::Msg::KillMultiplayerTest(cmd) => {
            // Drop the matching handle within the targeted session.
            // Server pid match → drop the whole session (cascades to clients).
            // Client pid match → remove just that client from the session.
            let mut guard = state.lock().await;
            let session_guid = cmd.session_guid.clone();
            let pid = cmd.pid;

            // Is this the server for the given session?
            let is_server = guard.multiplayer_test_session_meta.get(&session_guid)
                .map_or(false, |m| m.server.pid == pid);
            if is_server {
                tracing::info!(pid, session_guid = %session_guid, "killing play server (cascades to clients)");
                guard.multiplayer_test_sessions.remove(&session_guid);    // Drop cascades: clients all killed
                guard.multiplayer_test_session_meta.remove(&session_guid);
                return;
            }

            // Otherwise, a client within that session
            let client_idx = guard.multiplayer_test_sessions.get(&session_guid).and_then(|s| s.client_by_pid(pid));
            if let Some(idx) = client_idx {
                tracing::info!(pid, index = idx, session_guid = %session_guid, "killing play client");
                if let Some(session) = guard.multiplayer_test_sessions.get_mut(&session_guid) {
                    session.remove_client(idx);
                }
                if let Some(meta) = guard.multiplayer_test_session_meta.get_mut(&session_guid) {
                    meta.clients.remove(&idx);
                }
            } else {
                tracing::warn!(pid, session_guid = %session_guid, "kill_multiplayer_test: no handle found in session; falling back to libc::kill");
                unsafe { libc::kill(pid as i32, libc::SIGKILL); }
            }
        }
        proto::master_message::Msg::CloseStudio(cmd) => {
            let session_guid = cmd.session_guid.clone();
            let studio_to_cleanup = {
                let mut guard = state.lock().await;
                let trigger = guard.snapshot_trigger.clone();
                let studio = guard.studio_instances.get_mut(&session_guid).and_then(|inst| {
                    inst.status = "closing".to_string();
                    inst.studio.clone()
                });

                // Eagerly prune VMs belonging to the closing Studio so master's routing
                // view excludes them before the SIGTERM actually lands. Without this, the
                // window between kill-issue and WebSocket EOF allows new runs to match and
                // dispatch to a plugin that's about to die (and never reply).
                let dying: Vec<String> = guard.vms.iter()
                    .filter(|(_, vm)| vm.session_guid.as_deref() == Some(session_guid.as_str()))
                    .map(|(id, _)| id.clone())
                    .collect();
                for vm_id in &dying {
                    if let Some(vm) = guard.vms.get_mut(vm_id) {
                        vm.disconnect();
                    }
                    guard.vms.remove(vm_id);
                    if let Some(ref relay_tx) = guard.relay_tx {
                        let _ = relay_tx.send(proto::BackendMessage {
                            msg: Some(proto::backend_message::Msg::VmDisconnect(Box::new(proto::VmDisconnect {
                                vm_id: vm_id.clone(),
                                ..Default::default()
                            }))),
                            ..Default::default()
                        });
                    }
                }
                if !dying.is_empty() {
                    tracing::info!(session_guid = session_guid.as_str(), count = dying.len(), "pruned vms for closing studio");
                }

                if let Some(ref notify) = trigger {
                    notify.notify_one();
                }
                studio
            };
            if let Some(studio) = studio_to_cleanup {
                tracing::info!(session_guid = session_guid.as_str(), "closing Studio");
                // Run full cleanup (save if --save, skip kill if --detached) off the async
                // runtime — save() can block up to 30s waiting for file mtime change.
                let ls = state.clone();
                tokio::spawn(async move {
                    tokio::task::spawn_blocking(move || studio.cleanup()).await.ok();
                    let mut guard = ls.lock().await;
                    guard.studio_instances.remove(&session_guid);
                    if let Some(ref notify) = guard.snapshot_trigger {
                        notify.notify_one();
                    }
                });
            }
        }
        _ => {}
    }
}

/// Continuously mirror a Studio's log file to a destination path until the
/// Studio process exits or shutdown fires. Appends new bytes to `dst` as
/// Studio writes them. Used by LaunchStudio when `logs_dir` is set on the
/// request — lets callers tail -f the destination in real time to see
/// everything Studio outputs (including background task output from our
/// transition scripts, which doesn't land in any per-execution log dump).
async fn mirror_studio_log(
    src: std::path::PathBuf,
    dst: std::path::PathBuf,
    instance: std::sync::Arc<crate::studio_backend::Studio>,
    session_guid: String,
    shutdown: tokio_util::sync::CancellationToken,
) {
    use std::io::{Read, Seek, SeekFrom, Write};

    // Ensure destination directory exists.
    if let Some(parent) = dst.parent() {
        let _ = std::fs::create_dir_all(parent);
    }

    // Open mirror file (create/truncate — each Studio launch gets a fresh file).
    let mut out = match std::fs::OpenOptions::new().create(true).write(true).truncate(true).open(&dst) {
        Ok(f) => f,
        Err(e) => {
            tracing::warn!(session_guid = %session_guid, dst = %dst.display(), "log mirror: open failed: {e}");
            return;
        }
    };

    tracing::info!(session_guid = %session_guid, src = %src.display(), dst = %dst.display(), "log mirror: started");

    let mut offset: u64 = 0;
    let poll_interval = std::time::Duration::from_millis(200);
    loop {
        // Exit conditions: Studio process exited, or global shutdown requested.
        if !instance.is_running() {
            break;
        }
        if shutdown.is_cancelled() {
            break;
        }

        // Read any new bytes and append to dst.
        let read_result = tokio::task::spawn_blocking({
            let src = src.clone();
            move || -> std::io::Result<Vec<u8>> {
                let mut f = std::fs::File::open(&src)?;
                f.seek(SeekFrom::Start(offset))?;
                let mut buf = Vec::new();
                f.read_to_end(&mut buf)?;
                Ok(buf)
            }
        }).await;

        match read_result {
            Ok(Ok(buf)) if !buf.is_empty() => {
                let len = buf.len() as u64;
                if let Err(e) = out.write_all(&buf) {
                    tracing::warn!(session_guid = %session_guid, "log mirror: write failed: {e}");
                    break;
                }
                let _ = out.flush();
                offset += len;
            }
            Ok(Ok(_)) => {} // no new bytes this tick
            Ok(Err(e)) => {
                tracing::debug!(session_guid = %session_guid, "log mirror: read error (may be rotating): {e}");
            }
            Err(e) => {
                tracing::warn!(session_guid = %session_guid, "log mirror: spawn_blocking join: {e}");
                break;
            }
        }

        tokio::time::sleep(poll_interval).await;
    }

    // Flush any final bytes.
    if let Ok(buf) = std::fs::read(&src) {
        if (buf.len() as u64) > offset {
            let _ = out.write_all(&buf[offset as usize..]);
            let _ = out.flush();
        }
    }

    tracing::info!(session_guid = %session_guid, dst = %dst.display(), "log mirror: stopped");
}

/// Break file data into FileChunk messages for gRPC streaming.
pub fn stream_file_chunks(filename: &str, execution_id: &str, data: &[u8]) -> Vec<proto::FileChunk> {
    const CHUNK_SIZE: usize = 64 * 1024;
    let mut chunks = Vec::new();
    for (i, chunk) in data.chunks(CHUNK_SIZE).enumerate() {
        let is_last = (i + 1) * CHUNK_SIZE >= data.len();
        chunks.push(proto::FileChunk {
            filename: filename.to_string(),
            execution_id: execution_id.to_string(),
            data: chunk.to_vec(),
            is_last,
            ..Default::default()
        });
    }
    if chunks.is_empty() {
        chunks.push(proto::FileChunk {
            filename: filename.to_string(),
            execution_id: execution_id.to_string(),
            data: vec![],
            is_last: true,
            ..Default::default()
        });
    }
    chunks
}

async fn build_state_snapshot(state: &SharedBackendState) -> proto::StateSnapshot {
    let guard = state.lock().await;
    let vms = guard.vms.iter().map(|(vm_id, vm)| proto::VmSnapshot {
        vm_id: vm_id.clone(),
        mode: vm.state.as_ref().map(|s| s.mode.clone()),
        dom: vm.state.as_ref().map(|s| s.dom.clone()),
        session_guid: vm.session_guid.clone(),
        place_id: vm.state.as_ref().map(|s| s.place_id),
        game_name: vm.state.as_ref().map(|s| s.game_name.clone()),
        active_runs: vm.active_count() as u32,
        connected: vm.connected,
        ..Default::default()
    }).collect();
    let studios = guard.studios.iter().map(|(_, s)| proto::StudioSnapshot {
        session_guid: s.session_guid.clone(), mode: s.mode.clone(), name: s.name.clone(), place_id: s.place_id,
        ..Default::default()
    }).collect();
    let studio_instances = guard.studio_instances.values().map(|inst| proto::StudioInstanceState {
        session_guid: inst.session_guid.clone(),
        status: inst.status.clone(),
        error: inst.error.clone(),
        ..Default::default()
    }).collect();
    proto::StateSnapshot { vms, studios, studio_instances, ..Default::default() }
}

