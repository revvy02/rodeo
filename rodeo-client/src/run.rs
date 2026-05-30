use std::collections::HashMap;
use std::sync::Arc;

use anyhow::{anyhow, Result};
use tokio::sync::{mpsc, Mutex};
use tokio::task::JoinHandle;

use crate::proto;
use crate::runtime;
use crate::transport::Transport;

/// User-facing options for `Vm::run_code`.
#[derive(Default, Clone)]
pub struct RunCodeOpts {
    pub source: String,
    /// Target override (e.g. "run:server"). Falls back to the VM's native target.
    pub target: Option<String>,
    pub show_return: bool,
    pub cache_requires: bool,
    pub verbose: bool,
    pub script_args: Vec<String>,
    pub profile: bool,
    pub logs: bool,
    pub process_name: Option<String>,
    pub log_filter: Option<proto::LogFilter>,
    pub instance_path: Option<String>,
    pub script_path: Option<String>,
    pub return_file: Option<String>,
    pub output_file: Option<String>,
    pub profile_dir: Option<std::path::PathBuf>,
    pub logs_dir: Option<std::path::PathBuf>,
    pub job: Option<String>,
}

/// Buffered result of `Vm::run_code` — aligns with the TS RunResult shape.
#[derive(Default)]
pub struct RunResult {
    pub exit_code: i32,
    pub ok: bool,
    pub output: String,
    pub files: HashMap<String, Vec<u8>>,
    /// JSON-encoded return value from the script, untouched. `None` if the
    /// script didn't return anything. Clients are expected to `JSON.parse` /
    /// `json.deserialize` and surface as `result.return`.
    pub return_value: Option<String>,
}

/// Streaming event emitted by `Vm::run_code_stream`. Mirrors the JSON-RPC
/// daemon's `stream.data` payload shapes so the daemon can emit these directly.
pub enum RunStreamEvent {
    /// A chunk of bytes the running script wrote to its stdout or stderr.
    Output { kind: runtime::CapturedStreamKind, chunk: String },
    RpcCall { call: Box<proto::runtime::ClientRpcCall> },
    FileChunk { filename: String, data: Vec<u8>, is_last: bool },
    /// Terminal: execution finished (success, failure, or kill). The result's
    /// `ok`/`exit_code` fields carry the outcome. Killed runs produce
    /// `ok=false, exit_code=1`; disconnects produce `ok=false, exit_code=2`.
    Done { result: RunResult },
}

pub struct RunStream {
    rx: mpsc::UnboundedReceiver<RunStreamEvent>,
    _task: JoinHandle<()>,
}

impl RunStream {
    pub async fn next(&mut self) -> Option<RunStreamEvent> {
        self.rx.recv().await
    }
}

/// Core runner — opens a bidi stream, loops, and feeds events into a channel.
/// Returns the JoinHandle + the receiver for the channel. Used by both the
/// buffered and streaming APIs.
async fn run_inner(
    transport: Arc<Transport>,
    vm_id: &str,
    session_guid: Option<String>,
    opts: RunCodeOpts,
) -> Result<(
    mpsc::UnboundedReceiver<RunStreamEvent>,
    JoinHandle<()>,
)> {
    let client = transport.run_service();
    let mut bidi = client.run().await
        .map_err(|e| anyhow!("failed to open run stream (is 'rodeo serve' running?): {e}"))?;

    let execution_id = uuid::Uuid::new_v4().to_string();
    let submit = proto::SubmitRequest {
        execution_id: execution_id.clone(),
        script: opts.source,
        target: opts.target.unwrap_or_default(),
        session: session_guid,
        vm_id: if vm_id.is_empty() { None } else { Some(vm_id.to_string()) },
        job: opts.job,
        log_filter: opts.log_filter.map(buffa::MessageField::some).unwrap_or_else(buffa::MessageField::none),
        cache_requires: if opts.cache_requires { Some(true) } else { None },
        script_args: opts.script_args,
        return_file: opts.return_file,
        show_return: if opts.show_return { Some(true) } else { None },
        output_file: opts.output_file,
        verbose: if opts.verbose { Some(true) } else { None },
        instance_path: opts.instance_path,
        script_path: opts.script_path,
        process_name: opts.process_name,
        profile: if opts.profile { Some(true) } else { None },
        logs: if opts.logs { Some(true) } else { None },
        ..Default::default()
    };
    bidi.send(proto::RunClientMessage {
        msg: Some(proto::run_client_message::Msg::Submit(Box::new(submit))),
        ..Default::default()
    })
        .await
        .map_err(|e| anyhow!("failed to send submit: {e}"))?;

    let (event_tx, event_rx) = mpsc::unbounded_channel::<RunStreamEvent>();
    let profile_dir = opts.profile_dir.clone();
    let logs_dir = opts.logs_dir.clone();

    let task = tokio::spawn(async move {
        message_loop(&mut bidi, &execution_id, profile_dir, logs_dir, event_tx).await;
    });

    Ok((event_rx, task))
}

pub(crate) async fn run_stream(
    transport: Arc<Transport>,
    vm_id: &str,
    session_guid: Option<String>,
    opts: RunCodeOpts,
) -> Result<RunStream> {
    let (rx, task) = run_inner(transport, vm_id, session_guid, opts).await?;
    Ok(RunStream { rx, _task: task })
}

/// Target-routed streaming variant — empty `vm_id` tells the server to route
/// by the opts' `target` field. Used by CLI paths that rely on master-side
/// routing (e.g. `rodeo run --target play:server`).
pub(crate) async fn run_stream_target(
    transport: Arc<Transport>,
    opts: RunCodeOpts,
) -> Result<RunStream> {
    run_stream(transport, "", None, opts).await
}

pub(crate) async fn run_buffered_target(
    transport: Arc<Transport>,
    opts: RunCodeOpts,
) -> Result<RunResult> {
    // vm_id empty → server routes by target
    run_buffered(transport, "", None, opts).await
}

pub(crate) async fn run_buffered(
    transport: Arc<Transport>,
    vm_id: &str,
    session_guid: Option<String>,
    opts: RunCodeOpts,
) -> Result<RunResult> {
    let (mut rx, task) = run_inner(transport, vm_id, session_guid, opts).await?;
    let mut output = String::new();
    let mut files: HashMap<String, Vec<u8>> = HashMap::new();
    let mut exit_code = 0;
    let mut ok = true;
    let mut return_value: Option<String> = None;
    while let Some(ev) = rx.recv().await {
        match ev {
            RunStreamEvent::Output { kind: _, chunk } => output.push_str(&chunk),
            RunStreamEvent::FileChunk { filename, data, is_last: _ } => {
                files.entry(filename).or_default().extend_from_slice(&data);
            }
            RunStreamEvent::Done { result } => {
                output = if result.output.is_empty() { output } else { result.output };
                exit_code = result.exit_code;
                ok = result.ok;
                for (k, v) in result.files { files.insert(k, v); }
                return_value = result.return_value;
                break;
            }
            RunStreamEvent::RpcCall { .. } => {}
        }
    }
    let _ = task.await;
    Ok(RunResult { exit_code, ok, output, files, return_value })
}

/// The bidi message loop — drains incoming events, forwards them as
/// `RunStreamEvent`s, and handles client-side RPC dispatch against the local
/// filesystem/stdio. Returns after `Done`, `Killed`, or `Disconnected`.
async fn message_loop(
    bidi: &mut connectrpc::client::BidiStream<hyper::body::Incoming, proto::RunClientMessage, proto::RunEventView<'static>>,
    execution_id: &str,
    profile_dir: Option<std::path::PathBuf>,
    logs_dir: Option<std::path::PathBuf>,
    event_tx: mpsc::UnboundedSender<RunStreamEvent>,
) {
    // The runtime unconditionally routes script stdout/stderr writes through
    // this channel — it never touches the process's real std streams. Each
    // consumer (CLI, daemon, programmatic) decides where the bytes go.
    //
    // We drain this channel inline inside the main `select!` (alongside bidi
    // events and rpc responses) rather than in a separate task: with a task,
    // it's possible for Complete to arrive and emit `Done` before the task
    // has forwarded the last captured bytes, leaving trailing Output events
    // stranded. An inline branch plus an explicit drain at ExecutionDone
    // keeps ordering deterministic — all Output events for this execution
    // land in `event_tx` before `Done`.
    let (capture_tx, mut capture_rx) =
        mpsc::unbounded_channel::<(runtime::CapturedStreamKind, Vec<u8>)>();
    let rpc_state = Arc::new(Mutex::new(runtime::RpcState::new(capture_tx)));
    let forward_captured = |kind: runtime::CapturedStreamKind, bytes: Vec<u8>| {
        let chunk = String::from_utf8_lossy(&bytes).into_owned();
        let _ = event_tx.send(RunStreamEvent::Output { kind, chunk });
    };

    let mut rpc_tasks: Vec<JoinHandle<()>> = Vec::new();
    let mut file_buffers: HashMap<String, Vec<u8>> = HashMap::new();
    let mut exit_code = 0;
    let mut ok = true;
    let mut return_value: Option<String> = None;

    let (response_tx, mut response_rx) = mpsc::unbounded_channel::<proto::RunClientMessage>();

    loop {
        tokio::select! {
            event = bidi.message() => {
                match event {
                    Ok(Some(view)) => {
                        let event: proto::RunEvent = view.to_owned_message();
                        if let Some(evt) = event.event {
                            match evt {
                                proto::run_event::Event::Created(created) => {
                                    tracing::debug!(pid = created.process_id, "process created");
                                }
                                proto::run_event::Event::RpcCall(call) => {
                                    let state = rpc_state.clone();
                                    let tx = response_tx.clone();
                                    let observer = event_tx.clone();
                                    let call_boxed = call.clone();
                                    let handle = tokio::spawn(async move {
                                        let _ = observer.send(RunStreamEvent::RpcCall { call: Box::new(*call_boxed) });
                                        let response = runtime::dispatch_client(state, &call).await;
                                        let _ = tx.send(proto::RunClientMessage {
                                            msg: Some(proto::run_client_message::Msg::RpcResponse(Box::new(response))),
                                            ..Default::default()
                                        });
                                    });
                                    rpc_tasks.push(handle);
                                }
                                proto::run_event::Event::ExecutionDone(done) => {
                                    if !done.success { exit_code = 1; ok = false; }
                                    let rpc_exit = rpc_state.lock().await.exit_code;
                                    if rpc_exit != 0 { exit_code = rpc_exit; ok = false; }
                                    return_value = done.return_value.clone();
                                    for task in rpc_tasks.drain(..) { let _ = task.await; }
                                    // After every in-flight stream.write RPC has
                                    // resolved, drain any captured bytes they
                                    // produced so they reach event_tx BEFORE we
                                    // process Complete below.
                                    while let Ok((kind, bytes)) = capture_rx.try_recv() {
                                        forward_captured(kind, bytes);
                                    }
                                }
                                proto::run_event::Event::ExecutionKilled(_) => {
                                    // A kill is not an error to the caller — it's just a
                                    // completed run with ok=false. Let the normal
                                    // ExecutionDone/Complete flow carry the result (mirrors
                                    // the pre-refactor run_loop semantics; otherwise
                                    // `await runCode()` rejects and tests that await a
                                    // deliberate kill blow up).
                                    exit_code = 1;
                                    ok = false;
                                    for task in rpc_tasks.drain(..) { let _ = task.await; }
                                    while let Ok((kind, bytes)) = capture_rx.try_recv() {
                                        forward_captured(kind, bytes);
                                    }
                                }
                                proto::run_event::Event::Disconnect(_reason) => {
                                    // Stream is lost — server won't send Complete.
                                    // Synthesize a terminal Done with ok=false so
                                    // consumers don't hang waiting.
                                    let files_out = std::mem::take(&mut file_buffers);
                                    let _ = event_tx.send(RunStreamEvent::Done {
                                        result: RunResult {
                                            exit_code: 2,
                                            ok: false,
                                            output: String::new(),
                                            files: files_out,
                                            return_value: return_value.take(),
                                        },
                                    });
                                    break;
                                }
                                proto::run_event::Event::Complete(_) => {
                                    let files_out = std::mem::take(&mut file_buffers);
                                    // `output` on the Done event is left empty — the capture
                                    // pump is the canonical source of Output events, and
                                    // consumers that care about the string form reconstruct
                                    // it from those (run_buffered accumulates; the CLI shim
                                    // writes through + accumulates).
                                    let _ = event_tx.send(RunStreamEvent::Done {
                                        result: RunResult {
                                            exit_code,
                                            ok,
                                            output: String::new(),
                                            files: files_out,
                                            return_value: return_value.take(),
                                        },
                                    });
                                    break;
                                }
                                proto::run_event::Event::FileChunk(chunk) => {
                                    let buf = file_buffers.entry(chunk.filename.clone()).or_default();
                                    buf.extend_from_slice(&chunk.data);
                                    let _ = event_tx.send(RunStreamEvent::FileChunk {
                                        filename: chunk.filename.clone(),
                                        data: chunk.data.clone(),
                                        is_last: chunk.is_last,
                                    });
                                    if chunk.is_last {
                                        let is_log = chunk.filename.ends_with(".log");
                                        let dest = if is_log {
                                            logs_dir.as_ref().or(profile_dir.as_ref())
                                        } else {
                                            profile_dir.as_ref()
                                        };
                                        if let Some(dir) = dest {
                                            let _ = std::fs::create_dir_all(dir);
                                            let tmp = dir.join(format!("{}.tmp", &chunk.filename));
                                            let final_path = dir.join(&chunk.filename);
                                            if std::fs::write(&tmp, buf).is_ok() {
                                                let _ = std::fs::rename(&tmp, &final_path);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    _ => break,
                }
            }
            msg = response_rx.recv() => {
                if let Some(m) = msg {
                    let _ = bidi.send(m).await;
                }
            }
            captured = capture_rx.recv() => {
                if let Some((kind, bytes)) = captured {
                    forward_captured(kind, bytes);
                }
            }
        }
    }

    // Flush any open stream handlers to disk (matches the CLI's flush_streams).
    let mut guard = rpc_state.lock().await;
    let handles: Vec<String> = guard.stream_handlers.keys().cloned().collect();
    for handle in handles {
        if let Some(handler) = guard.stream_handlers.remove(&handle) {
            match handler {
                runtime::StreamHandler::FileWriter { path, buffer } => { let _ = std::fs::write(&path, &buffer); }
                runtime::StreamHandler::FileAppender { path, buffer } => { let _ = std::fs::write(&path, &buffer); }
                _ => {}
            }
        }
    }
    drop(guard);

    // Clean up any leftover temp files keyed by execution_id (same behavior as CLI)
    if let Some(content_path) = studio_content_path_fallback() {
        let temp_dir = std::path::Path::new(&content_path).join("rodeo-temp").join(execution_id);
        if temp_dir.exists() { let _ = std::fs::remove_dir_all(&temp_dir); }
    }
}

/// Locate the Studio `content/` directory via `roblox_install`. Same logic as
/// `rbx_control::studio::launch::studio_content_path`.
fn studio_content_path_fallback() -> Option<String> {
    roblox_install::RobloxStudio::locate()
        .ok()
        .map(|s| s.content_path().to_string_lossy().to_string())
}
