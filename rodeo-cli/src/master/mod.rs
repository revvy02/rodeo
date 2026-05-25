pub mod grpc;

use crate::studio_backend as studio_crate;
use rbx_control::studio::mcp_client::StudioMcpClient;
use rodeo_proto::ProcessState;
use tracing::info;
use crate::studio_backend::connection::{RunRequest, StudioInstance, VmConnection};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{mpsc, Mutex};

/// Message type for sending to run clients — typed variants only, no JSON tunneling.
pub enum ClientMsg {
    FileChunk(rodeo_proto::FileChunk),
    Complete,
    RpcCall(Box<rodeo_proto::runtime_types::ClientRpcCall>),
    ExecutionDone(Box<rodeo_proto::ExecutionDone>),
    ExecutionKilled(Box<rodeo_proto::ExecutionKilled>),
    Disconnect(String),
}

/// Play-mode server state (multi-process StartServer).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MultiplayerTestServerState {
    pub pid: u32,
    pub raknet_port: u16,
    /// RakNet/multiplayer session guid from StartServer's stdout. Distinct
    /// from the rodeo `session_guid` at `MultiplayerTestSessionMeta.session_guid`.
    pub raknet_session_guid: String,
    pub play_test_guid: String,
}

/// Play-mode client state (multi-process StartClient).
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MultiplayerTestClientState {
    pub pid: u32,
    pub index: u32,
}

/// Serializable metadata for one active multi-process play session. Mirrors
/// `studio::MultiplayerTestServer` + its clients in a form that can be sent to master
/// and exposed via GetState without carrying process handles.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MultiplayerTestSessionMeta {
    /// Master-minted session identity shared by MultiplayerTestServer + its MultiplayerTestClients.
    pub session_guid: String,
    pub server: MultiplayerTestServerState,
    /// Keyed by per-session client index (1-based).
    pub clients: HashMap<u32, MultiplayerTestClientState>,
    /// `--no-hud` setting for this session — propagated to every client launch.
    #[serde(default)]
    pub no_hud: bool,
    /// Resolved published identifiers (only populated when the session was
    /// launched against a published place). Cached here so subsequent
    /// `LaunchMultiplayerTestClient` dispatches forward the same ids without
    /// re-resolving. 0 = anonymous / no published place.
    #[serde(default)]
    pub place_id: u64,
    #[serde(default)]
    pub universe_id: u64,
    #[serde(default)]
    pub place_version: u32,
}

/// Shared server state
/// A Studio instance managed by a backend.
pub struct StudioInstanceInfo {
    /// Master-minted session identity for this Studio launch. Baked into the
    /// plugin's `flags.SESSION_GUID` so the plugin sends it on handshake and
    /// master stamps `VmConnection.session_guid` synchronously.
    pub session_guid: String,
    pub status: String, // "pending" | "launching" | "connected" | "closing" | "error"
    pub studio: Option<Arc<studio_crate::Studio>>,
    pub error: Option<String>,
    /// StudioMCP's id for this Studio process, resolved asynchronously by
    /// polling `list_roblox_studios` after spawn. Used only at the
    /// elevated-call boundary (`set_active_studio`) — not for routing.
    pub mcp_studio_id: Option<String>,
}


pub struct BackendState {
    /// All connected VMs, keyed by vmId
    pub vms: HashMap<String, VmConnection>,
    /// Studios derived from VMs, keyed by studioId
    pub studios: HashMap<String, StudioInstance>,
    /// Registered remote backends, keyed by backend ID
    pub backends: HashMap<String, grpc::BackendConnection>,
    pub pending_runs: Vec<RunRequest>,
    /// Studio instances managed by this backend, keyed by master-assigned studio_id
    pub studio_instances: HashMap<String, StudioInstanceInfo>,
    pub mcp: Arc<Mutex<Option<StudioMcpClient>>>,
    /// Notify to trigger an immediate state snapshot (event-driven)
    pub snapshot_trigger: Option<Arc<tokio::sync::Notify>>,
    /// When set, plugin_ws relays messages to master via this channel (backend mode).
    pub relay_tx: Option<mpsc::UnboundedSender<rodeo_proto::BackendMessage>>,
    /// Profile scanner for collecting microprofiler dumps
    pub profile_scanner: Option<rbx_control::profile_scanner::ProfileScannerHandle>,
    /// Log scanner for pairing Studios with their log files (notify-based)
    pub log_scanner: Option<rbx_control::studio::log_scanner::LogScannerHandle>,
    /// Active log-dump runs: execution_id → (log file path, byte offset at run start)
    pub log_runs: HashMap<String, (std::path::PathBuf, u64)>,
    /// Channel to trigger log dumps from plugin_ws relay path to run_master_loop
    pub log_dump_tx: Option<mpsc::UnboundedSender<LogDumpTask>>,
    /// Active multiplayer test sessions, keyed by session_id (UUID). Each
    /// `MultiplayerTestServer` owns its `clients` HashMap so dropping a session entry
    /// cascades to all its client processes via launch_control::Child's Drop.
    pub multiplayer_test_sessions: HashMap<String, studio_crate::MultiplayerTestServer>,
    /// Serializable metadata mirror of `multiplayer_test_sessions`, kept in sync so state
    /// snapshots don't need to reach into process handles.
    pub multiplayer_test_session_meta: HashMap<String, MultiplayerTestSessionMeta>,
    /// Local port this backend listens on (for Studio plugin connections)
    pub port: u16,
    /// Cancellation token for graceful shutdown — SIGTERM cancels this
    pub shutdown_token: tokio_util::sync::CancellationToken,
    /// Master's bootstrap UUID, learned from `RegisterResponse.master_id`.
    /// Used as a tracing span field so log lines from this backend can be
    /// correlated with master's logs by `jq 'select(.master_id=="…")'`.
    pub master_id: String,
}

impl BackendState {
    pub fn new() -> Self {
        Self {
            vms: HashMap::new(),
            studios: HashMap::new(),
            backends: HashMap::new(),
            pending_runs: Vec::new(),
            studio_instances: HashMap::new(),
            mcp: Arc::new(Mutex::new(None)),
            snapshot_trigger: None,
            relay_tx: None,
            multiplayer_test_sessions: HashMap::new(),
            multiplayer_test_session_meta: HashMap::new(),
            port: 0,
            shutdown_token: tokio_util::sync::CancellationToken::new(),
            profile_scanner: None,
            log_scanner: None,
            log_runs: HashMap::new(),
            log_dump_tx: None,
            master_id: String::new(),
        }
    }

    // --- VM lookup helpers ---

    /// Check if any VMs are still unresolved by StudioMCP reconciliation
    /// (i.e. haven't had their mcp_studio_id populated yet).
    fn has_unresolved(&self) -> bool {
        self.vms.values().any(|vm| {
            vm.connected && vm.state.as_ref().map_or(true, |s| s.mcp_studio_id.is_none())
        })
    }

    // --- Routing ---

    /// Try to find a matching VM for a run request.
    /// Priority: --vm (direct ID) > --target (mode/dom matching) > any connected VM.
    fn find_match_for_run(&self, run: &RunRequest) -> Option<String> {
        // Direct VM targeting by ID
        if let Some(ref wanted_vm) = run.vm_id {
            if let Some(vm) = self.vms.get(wanted_vm) {
                if vm.connected {
                    return Some(wanted_vm.clone());
                }
            }
            return None; // Specific VM requested but not found/connected
        }

        let parsed = if !run.target.is_empty() {
            crate::shared::target::parse(&run.target).ok()
        } else {
            None
        };

        let mut best: Option<(String, usize)> = None;

        for (vm_id, vm) in &self.vms {
            if !vm.connected {
                continue;
            }

            // Job filter: match by gameInstanceId if specified
            if let Some(ref wanted_job) = run.job {
                // TODO: check vm.state.job_id once live VMs report it
                let _ = wanted_job; // placeholder
            }

            if let Some(ref t) = parsed {
                // Mode-aware matching using VM's reported state
                let vm_mode = match vm.mode() {
                    Some(m) => m,
                    None => continue, // No state yet, skip
                };
                let vm_dom = match vm.dom() {
                    Some(d) => d,
                    None => continue,
                };

                // Check mode matches
                if t.mode.as_str() != vm_mode {
                    continue;
                }

                // Check dom matches
                let target_dom = match t.dom {
                    crate::shared::target::Dom::Edit => "edit",
                    crate::shared::target::Dom::Server => "server",
                    crate::shared::target::Dom::Client => "client",
                };
                if target_dom != vm_dom {
                    continue;
                }

                // Session filter — `run.session` is the master-minted session_guid.
                if let Some(ref wanted) = run.session {
                    let vm_session = vm.session_guid.as_deref();
                    if vm_session != Some(wanted.as_str()) {
                        continue;
                    }
                }
            }

            // Load balance: prefer VM with fewest active runs
            let count = vm.active_count();
            match &best {
                Some((_, best_count)) if count >= *best_count => {}
                _ => {
                    best = Some((vm_id.clone(), count));
                }
            }
        }

        best.map(|(vm_id, _)| vm_id)
    }

    /// Complete a run (done/killed) and update state.
    ///
    /// For profiled runs: the run stays in active_runs (draining state) so SendFile
    /// can still forward files to the client. FilesComplete removes it later.
    /// For non-profiled runs: removed immediately, Complete sent to client.
    pub fn complete_run(
        &mut self,
        execution_id: &str,
        vm_id: &str,
        new_state: ProcessState,
    ) {
        let is_profiled = self.vms.get(vm_id)
            .and_then(|vm| vm.active_runs.get(execution_id))
            .map(|run| run.profile == Some(true))
            .unwrap_or(false);

        if is_profiled {
            // Keep run alive for file transfers. Tell backend to stop profiling.
            if let Some(vm) = self.vms.get_mut(vm_id) {
                vm.mark_done(execution_id, &new_state);
            }
            for backend in self.backends.values() {
                let _ = backend.tx.send(rodeo_proto::MasterMessage {
                    msg: Some(rodeo_proto::master_message::Msg::RunCompleted(Box::new(rodeo_proto::RunCompleted {
                        execution_id: execution_id.to_string(),
                        ..Default::default()
                    }))),
                    ..Default::default()
                });
            }
        } else {
            // Non-profiled: remove and send Complete
            if let Some(vm) = self.vms.get_mut(vm_id) {
                if let Some(run) = vm.complete_run(execution_id, &new_state) {
                    let _ = run.client_tx.send(ClientMsg::Complete);
                }
            }
        }

        self.process_pending();
    }

    /// Reactive: re-evaluate all pending runs against current state.
    /// Called after any state change (VM connect/disconnect, state update, run complete).
    pub fn process_pending(&mut self) {

        if self.pending_runs.is_empty() {
            return;
        }

        // Try to route pending runs to matching VMs
        let mut routed = Vec::new();
        for (i, run) in self.pending_runs.iter().enumerate() {
            if let Some(vm_id) = self.find_match_for_run(run) {
                routed.push((i, vm_id));
            }
        }

        for (i, vm_id) in routed.into_iter().rev() {
            let run = self.pending_runs.remove(i);
            let label = run.process_name.as_deref()
                .unwrap_or(&run.execution_id[..8.min(run.execution_id.len())]);
            info!(pid = run.process_id, label, vm = &vm_id[..8.min(vm_id.len())], "routed from queue");
            if let Some(vm) = self.vms.get_mut(&vm_id) {
                vm.start_run(run);
            }
        }

    }

}

pub type SharedBackendState = Arc<Mutex<BackendState>>;

// ---------------------------------------------------------------------------
// MasterState — pure snapshot-based, no per-VM channels
// ---------------------------------------------------------------------------

pub struct MasterState {
    /// Bootstrap UUID minted at master startup by `util::log_capture::init`.
    /// Advertised to backends via `RegisterResponse.master_id` for cross-host
    /// log correlation (`jq 'select(.master_id=="…")'`).
    pub master_id: String,
    /// Registered remote backends, keyed by backend ID
    pub backends: HashMap<String, grpc::BackendConnection>,
    /// Active runs on VMs, keyed by execution_id
    pub active_runs: HashMap<String, ActiveRun>,
    /// Pending run requests waiting for a matching VM
    pub pending_runs: Vec<RunRequest>,
    pub next_process_id: u32,
    /// Active multiplayer test sessions, keyed by session_id. Master mirrors
    /// backend's per-session state via MultiplayerTestServerReady/MultiplayerTestClientReady and
    /// MultiplayerTestServerExited messages.
    pub multiplayer_test_session_meta: HashMap<String, MultiplayerTestSessionMeta>,
    /// `--no-hud` setting recorded at LaunchStudioServer time so that subsequent
    /// ConnectClient RPCs can forward it into LaunchMultiplayerTestClientCommand.
    /// Keyed by session_guid; cleared on session exit.
    pub multiplayer_test_no_hud: HashMap<String, bool>,
    /// In-flight save RPCs: master sends a typed SaveCommand on the control
    /// stream, studio backend replies with SaveResult, and this map routes the
    /// reply back to the awaiting save_place handler via a one-shot channel
    /// keyed by request_id (a UUID minted per-RPC). Using request_id rather
    /// than session_guid keeps routing independent of payload — session_guid
    /// is optional on the wire (CLI saves without specifying one), so it
    /// can't serve as the routing key.
    pub pending_saves: HashMap<String, tokio::sync::oneshot::Sender<rodeo_proto::SaveResult>>,
    /// In-flight `launch_multiplayer_test_server` streams: keyed by session_guid,
    /// fired with Ready once the VM registers, or Error if `SessionExited` arrives
    /// first (pre-handoff Studio crash). Removing the entry implicitly closes the
    /// stream from master's side. Exists symmetrically to how launch_studio
    /// watches studio_instances; using a sender map (rather than polling state_rx)
    /// makes the failure event point-to-point and zero-latency.
    pub pending_mp_launches: HashMap<String, tokio::sync::mpsc::UnboundedSender<rodeo_proto::LaunchMultiplayerTestServerEvent>>,
    /// Declarative per-studio target mode, paired with the studio's VM set
    /// fingerprint at last broadcast. We re-broadcast whenever either changes:
    /// target change is obvious; VM-set change covers the exit→enter handoff
    /// (server VM disconnects after EndTest, then edit VM needs a fresh push
    /// to fire ExecuteRunModeAsync now that the session is clear).
    /// Value: (target_mode, sorted vm_ids).
    pub target_modes: HashMap<String, (String, Vec<String>)>,
}

/// A run that's been routed to a VM and is executing.
pub struct ActiveRun {
    pub execution_id: String,
    pub vm_id: String,
    pub process_id: u32,
    pub process_name: Option<String>,
    pub client_tx: mpsc::UnboundedSender<ClientMsg>,
    pub state: ProcessState,
    pub profile: Option<bool>,
    pub logs: Option<bool>,
    pub created_at: f64,
}

/// Task sent from plugin_ws relay path to run_master_loop to perform a log dump.
pub struct LogDumpTask {
    pub execution_id: String,
    /// Owning Studio's session_guid — baked into the dump filename for
    /// `ls | grep <session_guid>` correlation. Empty if the VM wasn't stamped
    /// (shouldn't happen post-handshake, but defensive).
    pub session_guid: String,
    pub log_path: std::path::PathBuf,
    pub start_offset: u64,
}

impl MasterState {
    pub fn new(master_id: String) -> Self {
        Self {
            master_id,
            backends: HashMap::new(),
            active_runs: HashMap::new(),
            pending_runs: Vec::new(),
            next_process_id: 0,
            multiplayer_test_session_meta: HashMap::new(),
            multiplayer_test_no_hud: HashMap::new(),
            pending_saves: HashMap::new(),
            pending_mp_launches: HashMap::new(),
            target_modes: HashMap::new(),
        }
    }

    pub fn next_pid(&mut self) -> u32 {
        self.next_process_id += 1;
        self.next_process_id
    }

    /// Get all VMs across all backends from their latest snapshots.
    fn all_vms(&self) -> Vec<(String, rodeo_proto::VmSnapshot)> {
        let mut result = Vec::new();
        for (backend_id, backend) in &self.backends {
            let snap = backend.state_rx.borrow();
            for vm in &snap.vms {
                let mut vm = vm.clone();
                vm.backend_id = Some(backend_id.clone());
                result.push((vm.vm_id.clone(), vm));
            }
        }
        result
    }

    /// Find the backend that owns a VM (by checking snapshots).
    fn backend_for_vm(&self, vm_id: &str) -> Option<&grpc::BackendConnection> {
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            if snap.vms.iter().any(|v| v.vm_id == vm_id) {
                return Some(backend);
            }
        }
        None
    }

    /// Send a typed ServerMessage to a VM's plugin via its backend's control stream.
    pub fn send_to_vm(&self, vm_id: &str, message: rodeo_proto::ServerMessage) {
        let kind = match &message.msg {
            Some(rodeo_proto::server_message::Msg::Welcome(_)) => "welcome",
            Some(rodeo_proto::server_message::Msg::Run(_)) => "run",
            Some(rodeo_proto::server_message::Msg::Kill(_)) => "kill",
            Some(rodeo_proto::server_message::Msg::RpcResponse(_)) => "rpc_response",
            Some(rodeo_proto::server_message::Msg::SetTargetMode(_)) => "set_target_mode",
            None => "empty",
        };
        let vm_short = &vm_id[..8.min(vm_id.len())];
        if let Some(backend) = self.backend_for_vm(vm_id) {
            let send_res = backend.tx.send(rodeo_proto::MasterMessage {
                msg: Some(rodeo_proto::master_message::Msg::VmServerMessage(Box::new(rodeo_proto::VmServerMessage {
                    vm_id: vm_id.to_string(),
                    message: buffa::MessageField::some(message),
                    ..Default::default()
                }))),
                ..Default::default()
            });
            let backend_short = &backend.id[..8.min(backend.id.len())];
            if let Err(e) = send_res {
                tracing::warn!(vm = vm_short, kind, backend = backend_short, "send_to_vm: backend tx send failed: {e}");
            } else {
                tracing::debug!(vm = vm_short, kind, backend = backend_short, "send_to_vm: forwarded");
            }
        } else {
            tracing::warn!(vm = vm_short, kind, "send_to_vm: no backend found for VM");
        }
    }

    /// Find a matching VM for a run request using proto snapshots.
    pub fn find_match_for_run(&self, run: &RunRequest) -> Option<String> {
        // Direct VM targeting by ID
        if let Some(ref wanted_vm) = run.vm_id {
            // Check if VM exists in any backend snapshot
            if self.backend_for_vm(wanted_vm).is_some() {
                return Some(wanted_vm.clone());
            }
            return None;
        }

        let parsed = if !run.target.is_empty() {
            crate::shared::target::parse(&run.target).ok()
        } else {
            None
        };

        let all_vms = self.all_vms();
        let mut best: Option<(String, usize)> = None;

        for (vm_id, vm) in &all_vms {
            if !vm.connected {
                continue;
            }

            if let Some(ref t) = parsed {
                let vm_mode = vm.mode.as_deref().unwrap_or("");
                let vm_dom = vm.dom.as_deref().unwrap_or("");

                if t.mode.as_str() != vm_mode {
                    continue;
                }
                let target_dom = match t.dom {
                    crate::shared::target::Dom::Edit => "edit",
                    crate::shared::target::Dom::Server => "server",
                    crate::shared::target::Dom::Client => "client",
                };
                if target_dom != vm_dom {
                    continue;
                }

                if let Some(ref wanted) = run.session {
                    if vm.session_guid.as_deref() != Some(wanted.as_str()) {
                        continue;
                    }
                }
            }

            let count = vm.active_runs as usize;
            match &best {
                Some((_, best_count)) if count >= *best_count => {}
                _ => { best = Some((vm_id.clone(), count)); }
            }
        }

        best.map(|(vm_id, _)| vm_id)
    }

    /// Build a RunCommand proto from a RunRequest.
    fn build_run_command(run: &RunRequest) -> rodeo_proto::ServerMessage {
        rodeo_proto::ServerMessage {
            msg: Some(rodeo_proto::server_message::Msg::Run(Box::new(rodeo_proto::RunCommand {
                execution_id: run.execution_id.clone(),
                script: run.script.clone(),
                target: if run.target.is_empty() { String::new() } else {
                    crate::shared::target::parse(&run.target).ok()
                        .map(|t| t.identity.as_str().to_string())
                        .unwrap_or_default()
                },
                log_filter: buffa::MessageField::some(run.log_filter.clone()),
                cache_requires: run.cache_requires,
                script_args: run.script_args.clone().unwrap_or_default(),
                return_file: run.return_file.clone(),
                show_return: run.show_return,
                output_file: run.output_file.clone(),
                verbose: run.verbose,
                instance_path: run.instance_path.clone(),
                script_path: run.script_path.clone(),
                profile: run.profile,
                logs: run.logs,
                ..Default::default()
            }))),
            ..Default::default()
        }
    }

    /// Send a run command to a VM and track it as active.
    fn dispatch_run(&mut self, vm_id: &str, run: RunRequest) {
        // Look up VM's canonical studio_id from snapshot for log correlation.
        let studio = {
            let mut studio = None;
            for backend in self.backends.values() {
                let snap = backend.state_rx.borrow();
                if let Some(v) = snap.vms.iter().find(|v| v.vm_id == vm_id) {
                    studio = v.session_guid.clone();
                    break;
                }
            }
            studio
        };
        tracing::info!(
            pid = run.process_id,
            vm = &vm_id[..8.min(vm_id.len())],
            target = run.target.as_str(),
            studio = studio.as_deref().map(|s| &s[..8.min(s.len())]).unwrap_or("-"),
            execution_id = run.execution_id.as_str(),
            process_name = run.process_name.as_deref().unwrap_or(""),
            "dispatch"
        );
        let cmd = Self::build_run_command(&run);
        self.send_to_vm(vm_id, cmd);
        self.active_runs.insert(run.execution_id.clone(), ActiveRun {
            execution_id: run.execution_id.clone(),
            vm_id: vm_id.to_string(),
            process_id: run.process_id,
            process_name: run.process_name.clone(),
            client_tx: run.client_tx,
            state: ProcessState::PROCESS_STATE_RUNNING,
            profile: run.profile,
            logs: run.logs,
            created_at: run.created_at,
        });
    }

    /// Route a run to a matching VM, or queue it as pending.
    pub fn route_or_queue(&mut self, run: RunRequest) -> bool {
        if let Some(vm_id) = self.find_match_for_run(&run) {
            self.dispatch_run(&vm_id, run);
            return true;
        }
        self.pending_runs.push(run);
        self.reconcile();
        false
    }

    /// Single entry point for all event-driven state reconciliation:
    /// re-route pending runs, drain runs targeting dead sessions, then
    /// push updated target_modes to studios' edit-VM plugins.
    pub fn reconcile(&mut self) {
        self.process_pending();
        self.drain_dead_sessions();
        self.derive_and_push_targets();
    }

    /// Re-evaluate pending runs against current backend snapshots.
    pub fn process_pending(&mut self) {
        if self.pending_runs.is_empty() {
            return;
        }
        let mut routed = Vec::new();
        for (i, run) in self.pending_runs.iter().enumerate() {
            if let Some(vm_id) = self.find_match_for_run(run) {
                routed.push((i, vm_id));
            }
        }
        for (i, vm_id) in routed.into_iter().rev() {
            let run = self.pending_runs.remove(i);
            let label = run.process_name.as_deref()
                .unwrap_or(&run.execution_id[..8.min(run.execution_id.len())]);
            info!(pid = run.process_id, label, vm = &vm_id[..8.min(vm_id.len())], "routed from queue");
            self.dispatch_run(&vm_id, run);
        }
    }

    /// Drain pending runs whose target session has no live VM. Without this,
    /// `runCode()` would hang forever waiting for a studio that's gone.
    /// Called alongside process_pending on every notify tick.
    pub fn drain_dead_sessions(&mut self) {
        if self.pending_runs.is_empty() {
            return;
        }

        // Collect session_guids that pending runs are targeting with a non-empty session.
        let targeted_sessions: std::collections::HashSet<String> = self.pending_runs.iter()
            .filter_map(|r| r.session.clone())
            .filter(|s| !s.is_empty())
            .collect();

        for scope_session in targeted_sessions {
            let alive = self.backends.values().any(|b| {
                b.state_rx.borrow().vms.iter().any(|v| {
                    v.connected && v.session_guid.as_deref() == Some(scope_session.as_str())
                })
            });
            if alive {
                continue;
            }

            let (drained, kept): (Vec<_>, Vec<_>) = self.pending_runs
                .drain(..)
                .partition(|r| r.session.as_deref() == Some(scope_session.as_str()));
            self.pending_runs = kept;
            for run in drained {
                let _ = run.client_tx.send(ClientMsg::ExecutionKilled(Box::new(
                    rodeo_proto::ExecutionKilled {
                        execution_id: run.execution_id.clone(),
                        ..Default::default()
                    },
                )));
                let _ = run.client_tx.send(ClientMsg::Complete);
                info!(
                    pid = run.process_id,
                    label = run.execution_id[..8.min(run.execution_id.len())].to_string().as_str(),
                    session = &scope_session[..8.min(scope_session.len())],
                    "pending run dropped: target session no longer alive",
                );
            }
        }
    }

    /// For each studio, compute the desired target mode from pending runs and
    /// broadcast SetTargetModeMsg to every VM. The plugin on each VM handles
    /// the target in a retry loop — edit VM keeps trying the enter script,
    /// server VM keeps trying EndTest — until its own mode matches (or the
    /// target changes). Backend just maintains the declarative state.
    pub fn derive_and_push_targets(&mut self) {
        let mut studio_vms: HashMap<String, Vec<String>> = HashMap::new();
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            for vm in &snap.vms {
                if !vm.connected { continue; }
                let Some(session) = vm.session_guid.as_deref() else { continue; };
                studio_vms.entry(session.to_string()).or_default().push(vm.vm_id.clone());
            }
        }
        for vms in studio_vms.values_mut() { vms.sort(); }

        let mut derived: HashMap<String, String> = HashMap::new();
        for session in studio_vms.keys() { derived.insert(session.clone(), String::new()); }
        let mut ordered: Vec<&RunRequest> = self.pending_runs.iter().collect();
        ordered.sort_by(|a, b| a.created_at.partial_cmp(&b.created_at).unwrap_or(std::cmp::Ordering::Equal));
        for run in ordered {
            if run.target.is_empty() { continue; }
            let Ok(t) = crate::shared::target::parse(&run.target) else { continue; };
            let mode = match t.mode {
                crate::shared::target::StudioMode::Run
                | crate::shared::target::StudioMode::Test
                | crate::shared::target::StudioMode::Play => t.mode.as_str().to_string(),
                _ => continue,
            };
            match run.session.as_deref() {
                Some(s) if !s.is_empty() => {
                    derived.entry(s.to_string()).and_modify(|v| {
                        if v.is_empty() { *v = mode.clone(); }
                    }).or_insert_with(|| mode.clone());
                }
                _ => {
                    for session in studio_vms.keys() {
                        derived.entry(session.clone()).and_modify(|v| {
                            if v.is_empty() { *v = mode.clone(); }
                        }).or_insert_with(|| mode.clone());
                    }
                }
            }
        }

        // Broadcast to every VM in the studio when target or VM set changed.
        let mut pushes: Vec<(String, String)> = Vec::new();
        let mut next_state: HashMap<String, (String, Vec<String>)> = HashMap::new();
        for (session, target) in &derived {
            let empty_vms: Vec<String> = Vec::new();
            let vms = studio_vms.get(session).unwrap_or(&empty_vms);
            let prev = self.target_modes.get(session);
            let changed = match prev {
                None => !target.is_empty(),
                Some((prev_target, prev_vms)) => prev_target != target || prev_vms != vms,
            };
            if changed {
                for vm_id in vms {
                    pushes.push((vm_id.clone(), target.clone()));
                }
            }
            next_state.insert(session.clone(), (target.clone(), vms.clone()));
        }
        self.target_modes = next_state;

        for (vm_id, target) in pushes {
            info!(vm = &vm_id[..8.min(vm_id.len())], target = target.as_str(), "push target_mode");
            let msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::SetTargetMode(Box::new(
                    rodeo_proto::SetTargetModeMsg { target_mode: target, ..Default::default() }
                ))),
                ..Default::default()
            };
            self.send_to_vm(&vm_id, msg);
        }
    }

    /// Explicitly set a studio's target mode (used by SetStudioMode RPC).
    /// Broadcasts to every VM in the studio regardless of pending queue.
    pub fn set_target_mode(&mut self, session_guid: &str, mode: &str) {
        let mut vms: Vec<String> = {
            let mut found = Vec::new();
            for backend in self.backends.values() {
                let snap = backend.state_rx.borrow();
                for vm in &snap.vms {
                    if !vm.connected { continue; }
                    if vm.session_guid.as_deref() != Some(session_guid) { continue; }
                    found.push(vm.vm_id.clone());
                }
            }
            found
        };
        if vms.is_empty() { return; }
        vms.sort();

        self.target_modes.insert(session_guid.to_string(), (mode.to_string(), vms.clone()));
        info!(target = mode, session = &session_guid[..8.min(session_guid.len())], vm_count = vms.len(), "set target_mode explicitly");
        for vm_id in vms {
            let msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::SetTargetMode(Box::new(
                    rodeo_proto::SetTargetModeMsg { target_mode: mode.to_string(), ..Default::default() }
                ))),
                ..Default::default()
            };
            self.send_to_vm(&vm_id, msg);
        }
    }

    /// Forward a typed ClientRpcCall from a VM's plugin to the run client.
    pub fn forward_rpc_call(&self, execution_id: &str, call: rodeo_proto::runtime_types::ClientRpcCall) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(ClientMsg::RpcCall(Box::new(call)));
            return true;
        }
        false
    }

    /// Forward a typed ExecutionDone event to the run client.
    pub fn forward_execution_done(&self, execution_id: &str, done: rodeo_proto::ExecutionDone) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(ClientMsg::ExecutionDone(Box::new(done)));
            return true;
        }
        false
    }

    /// Forward a typed ExecutionKilled event to the run client.
    pub fn forward_execution_killed(&self, execution_id: &str, killed: rodeo_proto::ExecutionKilled) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(ClientMsg::ExecutionKilled(Box::new(killed)));
            return true;
        }
        false
    }

    /// Complete a run (done/killed).
    pub fn complete_run(&mut self, execution_id: &str, new_state: ProcessState) {
        let run = self.active_runs.get(execution_id);
        let is_profiled = run.map(|r| r.profile == Some(true)).unwrap_or(false);
        let is_logs = run.map(|r| r.logs == Some(true)).unwrap_or(false);

        if is_profiled || is_logs {
            // Keep run alive until file transfers complete.
            if let Some(run) = self.active_runs.get_mut(execution_id) {
                run.state = new_state;
            }
            // Tell studio backend(s) — profile scanner unregisters on RunCompleted.
            for backend in self.backends.values() {
                let _ = backend.tx.send(rodeo_proto::MasterMessage {
                    msg: Some(rodeo_proto::master_message::Msg::RunCompleted(Box::new(rodeo_proto::RunCompleted {
                        execution_id: execution_id.to_string(),
                        ..Default::default()
                    }))),
                    ..Default::default()
                });
            }
        } else {
            if let Some(run) = self.active_runs.remove(execution_id) {
                let _ = run.client_tx.send(ClientMsg::Complete);
                let state_str = match new_state {
                    ProcessState::PROCESS_STATE_DONE => "done",
                    ProcessState::PROCESS_STATE_ERROR => "error",
                    ProcessState::PROCESS_STATE_KILLED => "killed",
                    _ => "unknown",
                };
                info!(pid = run.process_id, label = run.execution_id[..8.min(run.execution_id.len())].to_string().as_str(), state = state_str, "completed");
            }
        }

        self.reconcile();
    }

    /// Handle FilesComplete — all file transfers done; send Complete to client.
    pub fn handle_files_complete(&mut self, execution_id: &str) {
        if let Some(run) = self.active_runs.remove(execution_id) {
            let _ = run.client_tx.send(ClientMsg::Complete);
            tracing::debug!(execution_id, "sent Complete after files drained");
        }
    }

    /// Disconnect a run client: remove from pending, auto-kill if running.
    pub fn disconnect_run(&mut self, process_id: u32, execution_id: &str) {
        info!(pid = process_id, "run client disconnected");
        self.pending_runs.retain(|r| r.execution_id != execution_id);

        if let Some(run) = self.active_runs.get(execution_id) {
            // Auto-kill: send kill command to the VM
            let kill_msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::Kill(Box::new(rodeo_proto::KillCommand {
                    execution_id: execution_id.to_string(),
                    ..Default::default()
                }))),
                ..Default::default()
            };
            let vm_id_owned = run.vm_id.clone();
            self.send_to_vm(&vm_id_owned, kill_msg);
        }
    }

    /// Find a run by process ID.
    pub fn find_by_process_id(&self, pid: u32) -> Option<(&str, &str)> {
        // Check active runs
        for (eid, run) in &self.active_runs {
            if run.process_id == pid {
                return Some((eid.as_str(), &run.vm_id));
            }
        }
        None
    }

    /// Get the mode for a specific session from backend snapshots.
    pub fn mode_for_session(&self, session_guid: &str) -> Option<String> {
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            for vm in &snap.vms {
                if vm.session_guid.as_deref() == Some(session_guid) {
                    return vm.mode.clone();
                }
            }
        }
        None
    }

    /// Build a snapshot for GetState RPC from backend snapshots.
    pub fn snapshot(&self) -> rodeo_proto::RodeoSnapshot {
        let backends: Vec<rodeo_proto::BackendInfo> = self.backends.values().map(|b| {
            rodeo_proto::BackendInfo {
                id: b.id.clone(),
                kind: b.kind.clone(),
                name: b.name.clone(),
                ..Default::default()
            }
        }).collect();

        let mut vms = Vec::new();
        for (backend_id, backend) in &self.backends {
            let snap = backend.state_rx.borrow();
            for vm in &snap.vms {
                let mut vm = vm.clone();
                vm.backend_id = Some(backend_id.clone());
                vms.push(vm);
            }
        }

        let processes: Vec<rodeo_proto::ProcessInfo> = self.active_runs.values()
            .map(|r| rodeo_proto::ProcessInfo {
                process_id: r.process_id,
                execution_id: r.execution_id.clone(),
                state: match r.state {
                    ProcessState::PROCESS_STATE_RUNNING => "running",
                    ProcessState::PROCESS_STATE_DONE => "done",
                    ProcessState::PROCESS_STATE_ERROR => "error",
                    ProcessState::PROCESS_STATE_KILLED => "killed",
                    _ => "queued",
                }.to_string(),
                name: r.process_name.clone(),
                created_at: r.created_at,
                ..Default::default()
            })
            .chain(self.pending_runs.iter().map(|r| rodeo_proto::ProcessInfo {
                process_id: r.process_id,
                execution_id: r.execution_id.clone(),
                state: "queued".to_string(),
                name: r.process_name.clone(),
                created_at: r.created_at,
                ..Default::default()
            }))
            .collect();

        let multiplayer_test_sessions = self.multiplayer_test_session_meta.values().map(|m| rodeo_proto::SnapshotMultiplayerTestSession {
            session_guid: m.session_guid.clone(),
            server: buffa::MessageField::some(rodeo_proto::SnapshotMultiplayerTestServer {
                pid: m.server.pid,
                raknet_port: m.server.raknet_port as u32,
                raknet_session_guid: m.server.raknet_session_guid.clone(),
                play_test_guid: m.server.play_test_guid.clone(),
                ..Default::default()
            }),
            clients: m.clients.values().map(|c| rodeo_proto::SnapshotMultiplayerTestClient {
                index: c.index,
                pid: c.pid,
                ..Default::default()
            }).collect(),
            ..Default::default()
        }).collect();

        rodeo_proto::RodeoSnapshot {
            backends,
            vms,
            processes,
            multiplayer_test_sessions,
            ..Default::default()
        }
    }
}

pub type SharedMasterState = Arc<Mutex<MasterState>>;

/// Connect to StudioMCP and run the reconciliation loop.
#[tracing::instrument(name = "reconcile", skip_all)]
pub async fn run_reconciliation(state: SharedBackendState) {
    loop {
        match StudioMcpClient::new("rodeo").await {
            Ok(client) => {
                let guard = state.lock().await;
                *guard.mcp.lock().await = Some(client);
                info!("StudioMCP connected");
                break;
            }
            Err(_) => {
                tokio::time::sleep(std::time::Duration::from_secs(3)).await;
            }
        }
    }

    loop {
        let has_unresolved = {
            let guard = state.lock().await;
            guard.has_unresolved()
        };

        tracing::debug!(has_unresolved, "reconciliation tick");

        if has_unresolved {
            let mcp_arc = {
                let guard = state.lock().await;
                guard.mcp.clone()
            };

            tracing::debug!("acquiring mcp lock");
            let mut mcp_guard = mcp_arc.lock().await;
            tracing::debug!(has_mcp = mcp_guard.is_some(), "mcp lock acquired");

            if let Some(mcp) = mcp_guard.as_mut() {
                tracing::debug!("calling list_studios");
                match mcp.list_studios().await {
                    Ok(studios) => {
                        tracing::debug!(count = studios.len(), "list_studios returned");
                        for studio in &studios {
                            tracing::debug!(mcp_studio_id = studio.mcp_studio_id.as_str(), "setting active studio");
                            match mcp.set_active_studio(&studio.mcp_studio_id).await {
                                Ok(_) => {
                                    tracing::debug!("set_active_studio ok, executing unifier");
                                }
                                Err(e) => {
                                    tracing::debug!("set_active_studio failed: {e}");
                                    continue;
                                }
                            }
                            // Unify code fires the MCP studio id into the plugin so
                            // it populates its state.mcp_studio_id. Note: the event
                            // string keys ("studio_id_from_server"/_client) are kept
                            // as-is for plugin wire compatibility — the VALUE they
                            // carry is an mcp_studio_id.
                            let unify_code = format!(
                                r#"local u = game:GetService("ReplicatedStorage"):FindFirstChild("RODEO_UNIFIER") if not u then return end local RunService = game:GetService("RunService") if RunService:IsServer() then u.RemoteEvent:FireAllClients("studio_id_from_server", "{msid}") end if RunService:IsClient() then u.RemoteEvent:FireServer("studio_id_from_client", "{msid}") end u.BindableEvent:Fire("{msid}")"#,
                                msid = studio.mcp_studio_id,
                            );
                            match mcp.execute_luau(&unify_code).await {
                                Ok(r) => tracing::debug!(result = ?r, "execute_luau ok"),
                                Err(e) => tracing::debug!("execute_luau failed: {e}"),
                            }
                        }
                    }
                    Err(e) => {
                        tracing::debug!("list_studios failed: {e}");
                    }
                }
            }
        }

        let delay = if has_unresolved { 1 } else { 5 };
        tokio::time::sleep(std::time::Duration::from_secs(delay)).await;
    }
}
