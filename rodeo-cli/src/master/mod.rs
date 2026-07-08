pub mod grpc;

use crate::studio_backend as studio_crate;
use rbx_control::studio::mcp_client::StudioMcpClient;
use rodeo_proto::ProcessState;
use tracing::info;
use crate::studio_backend::connection::{RunRequest, StudioInstance, DomConnection};
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

/// Shared server state
/// A Studio instance managed by a backend.
pub struct StudioInstanceInfo {
    /// Master-minted session identity for this Studio launch. Baked into the
    /// plugin's `flags.SESSION_GUID` so the plugin sends it on handshake and
    /// master stamps `DomConnection.session_guid` synchronously.
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
    /// All connected DOMs, keyed by domId
    pub doms: HashMap<String, DomConnection>,
    /// Studios derived from DOMs, keyed by studioId
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
            doms: HashMap::new(),
            studios: HashMap::new(),
            backends: HashMap::new(),
            pending_runs: Vec::new(),
            studio_instances: HashMap::new(),
            mcp: Arc::new(Mutex::new(None)),
            snapshot_trigger: None,
            relay_tx: None,
            port: 0,
            shutdown_token: tokio_util::sync::CancellationToken::new(),
            profile_scanner: None,
            master_id: String::new(),
        }
    }

    // --- DOM lookup helpers ---

    /// Check if any DOMs are still unresolved by StudioMCP reconciliation
    /// (i.e. haven't had their mcp_studio_id populated yet).
    fn has_unresolved(&self) -> bool {
        self.doms.values().any(|dom| {
            dom.connected && dom.state.as_ref().map_or(true, |s| s.mcp_studio_id.is_none())
        })
    }

    // --- Routing ---

    /// Try to find a matching DOM for a run request.
    /// Priority: --dom (direct ID) > --target (mode/dom matching) > any connected DOM.
    fn find_match_for_run(&self, run: &RunRequest) -> Option<String> {
        // Direct DOM targeting by ID
        if let Some(ref wanted_dom) = run.dom_id {
            if let Some(dom) = self.doms.get(wanted_dom) {
                if dom.connected {
                    return Some(wanted_dom.clone());
                }
            }
            return None; // Specific DOM requested but not found/connected
        }

        let parsed = if !run.target.is_empty() {
            crate::shared::target::parse(&run.target).ok()
        } else {
            None
        };

        let mut best: Option<(String, usize)> = None;

        for (dom_id, dom) in &self.doms {
            if !dom.connected {
                continue;
            }

            // Session filter — `run.session` is the master-minted session_guid.
            // Applies regardless of target: a default-target run pinned to a
            // session (e.g. the Studio `run --place` just launched) must never
            // route into another session's DOMs.
            if let Some(ref wanted) = run.session {
                let dom_session = dom.session_guid.as_deref();
                if dom_session != Some(wanted.as_str()) {
                    continue;
                }
            }

            if let Some(ref t) = parsed {
                // Mode-aware matching using DOM's reported state
                let dom_mode = match dom.mode() {
                    Some(m) => m,
                    None => continue, // No state yet, skip
                };
                let vm_dom = match dom.dom_kind() {
                    Some(d) => d,
                    None => continue,
                };

                // Check mode matches
                if t.mode.as_str() != dom_mode {
                    continue;
                }

                // Check dom matches
                let target_dom = match t.dom_kind {
                    crate::shared::target::DomKind::Edit => "edit",
                    crate::shared::target::DomKind::Server => "server",
                    crate::shared::target::DomKind::Client => "client",
                };
                if target_dom != vm_dom {
                    continue;
                }
            }

            // Load balance: prefer DOM with fewest active runs
            let count = dom.active_count();
            match &best {
                Some((_, best_count)) if count >= *best_count => {}
                _ => {
                    best = Some((dom_id.clone(), count));
                }
            }
        }

        best.map(|(dom_id, _)| dom_id)
    }

    /// Complete a run (done/killed) and update state.
    ///
    /// For profiled runs: the run stays in active_runs (draining state) so SendFile
    /// can still forward files to the client. FilesComplete removes it later.
    /// For non-profiled runs: removed immediately, Complete sent to client.
    pub fn complete_run(
        &mut self,
        execution_id: &str,
        dom_id: &str,
        new_state: ProcessState,
    ) {
        let is_profiled = self.doms.get(dom_id)
            .and_then(|dom| dom.active_runs.get(execution_id))
            .map(|run| run.profile == Some(true))
            .unwrap_or(false);

        if is_profiled {
            // Keep run alive for file transfers. Tell backend to stop profiling.
            if let Some(dom) = self.doms.get_mut(dom_id) {
                dom.mark_done(execution_id, &new_state);
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
            if let Some(dom) = self.doms.get_mut(dom_id) {
                if let Some(run) = dom.complete_run(execution_id, &new_state) {
                    let _ = run.client_tx.send(ClientMsg::Complete);
                }
            }
        }

        self.process_pending();
    }

    /// Reactive: re-evaluate all pending runs against current state.
    /// Called after any state change (DOM connect/disconnect, state update, run complete).
    pub fn process_pending(&mut self) {

        if self.pending_runs.is_empty() {
            return;
        }

        // Try to route pending runs to matching DOMs
        let mut routed = Vec::new();
        for (i, run) in self.pending_runs.iter().enumerate() {
            if let Some(dom_id) = self.find_match_for_run(run) {
                routed.push((i, dom_id));
            }
        }

        for (i, dom_id) in routed.into_iter().rev() {
            let run = self.pending_runs.remove(i);
            info!(id = run.execution_id.as_str(), dom = &dom_id[..8.min(dom_id.len())], "routed from queue");
            if let Some(dom) = self.doms.get_mut(&dom_id) {
                dom.start_run(run);
            }
        }

    }

}

pub type SharedBackendState = Arc<Mutex<BackendState>>;

// ---------------------------------------------------------------------------
// MasterState — pure snapshot-based, no per-DOM channels
// ---------------------------------------------------------------------------

pub struct MasterState {
    /// Bootstrap UUID minted at master startup by `util::log_capture::init`.
    /// Advertised to backends via `RegisterResponse.master_id` for cross-host
    /// log correlation (`jq 'select(.master_id=="…")'`).
    pub master_id: String,
    /// Registered remote backends, keyed by backend ID
    pub backends: HashMap<String, grpc::BackendConnection>,
    /// Active runs on DOMs, keyed by execution_id
    pub active_runs: HashMap<String, ActiveRun>,
    /// Pending run requests waiting for a matching DOM
    pub pending_runs: Vec<RunRequest>,
    /// In-flight save RPCs: master sends a typed SaveCommand on the control
    /// stream, studio backend replies with SaveResult, and this map routes the
    /// reply back to the awaiting save_place handler via a one-shot channel
    /// keyed by request_id (a UUID minted per-RPC). Using request_id rather
    /// than session_guid keeps routing independent of payload — session_guid
    /// is optional on the wire (CLI saves without specifying one), so it
    /// can't serve as the routing key.
    pub pending_saves: HashMap<String, tokio::sync::oneshot::Sender<rodeo_proto::SaveResult>>,
    /// Declarative per-studio target mode, paired with the studio's DOM set
    /// fingerprint at last broadcast. We re-broadcast whenever either changes:
    /// target change is obvious; DOM-set change covers the exit→enter handoff
    /// (server DOM disconnects after EndTest, then edit DOM needs a fresh push
    /// to fire ExecuteRunModeAsync now that the session is clear).
    /// Value: (target_mode, sorted dom_ids).
    pub target_modes: HashMap<String, (String, Vec<String>)>,
}

/// A run that's been routed to a DOM and is executing.
pub struct ActiveRun {
    pub execution_id: String,
    pub dom_id: String,
    /// Requested target string (e.g. "edit:elevated"); empty for --dom-pinned
    /// runs that gave no target. Surfaced in the snapshot's process list.
    pub target: String,
    pub client_tx: mpsc::UnboundedSender<ClientMsg>,
    pub state: ProcessState,
    pub profile: Option<bool>,
    pub created_at: f64,
}

impl MasterState {
    pub fn new(master_id: String) -> Self {
        Self {
            master_id,
            backends: HashMap::new(),
            active_runs: HashMap::new(),
            pending_runs: Vec::new(),
            pending_saves: HashMap::new(),
            target_modes: HashMap::new(),
        }
    }

    /// Mint a run id: 12 hex chars, unique among live runs. The master is the
    /// sole id authority — clients never supply one — so uniqueness is a
    /// server guarantee rather than a client promise.
    pub fn mint_execution_id(&self) -> String {
        loop {
            let id = uuid::Uuid::new_v4().simple().to_string()[..12].to_string();
            if !self.active_runs.contains_key(&id)
                && !self.pending_runs.iter().any(|r| r.execution_id == id)
            {
                return id;
            }
        }
    }

    /// Get all DOMs across all backends from their latest snapshots.
    fn all_doms(&self) -> Vec<(String, rodeo_proto::DomSnapshot)> {
        let mut result = Vec::new();
        for (backend_id, backend) in &self.backends {
            let snap = backend.state_rx.borrow();
            for dom in &snap.doms {
                let mut dom = dom.clone();
                dom.backend_id = Some(backend_id.clone());
                result.push((dom.dom_id.clone(), dom));
            }
        }
        result
    }

    /// Find the backend that owns a DOM (by checking snapshots).
    fn backend_for_dom(&self, dom_id: &str) -> Option<&grpc::BackendConnection> {
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            if snap.doms.iter().any(|v| v.dom_id == dom_id) {
                return Some(backend);
            }
        }
        None
    }

    /// Send a typed ServerMessage to a DOM's plugin via its backend's control stream.
    pub fn send_to_dom(&self, dom_id: &str, message: rodeo_proto::ServerMessage) {
        let kind = match &message.msg {
            Some(rodeo_proto::server_message::Msg::Welcome(_)) => "welcome",
            Some(rodeo_proto::server_message::Msg::Run(_)) => "run",
            Some(rodeo_proto::server_message::Msg::Kill(_)) => "kill",
            Some(rodeo_proto::server_message::Msg::RpcResponse(_)) => "rpc_response",
            Some(rodeo_proto::server_message::Msg::SetTargetMode(_)) => "set_target_mode",
            None => "empty",
        };
        let dom_short = &dom_id[..8.min(dom_id.len())];
        if let Some(backend) = self.backend_for_dom(dom_id) {
            let send_res = backend.tx.send(rodeo_proto::MasterMessage {
                msg: Some(rodeo_proto::master_message::Msg::DomServerMessage(Box::new(rodeo_proto::DomServerMessage {
                    dom_id: dom_id.to_string(),
                    message: buffa::MessageField::some(message),
                    ..Default::default()
                }))),
                ..Default::default()
            });
            let backend_short = &backend.id[..8.min(backend.id.len())];
            if let Err(e) = send_res {
                tracing::warn!(dom = dom_short, kind, backend = backend_short, "send_to_dom: backend tx send failed: {e}");
            } else {
                tracing::debug!(dom = dom_short, kind, backend = backend_short, "send_to_dom: forwarded");
            }
        } else {
            tracing::warn!(dom = dom_short, kind, "send_to_dom: no backend found for DOM");
        }
    }

    /// Find a matching DOM for a run request using proto snapshots.
    pub fn find_match_for_run(&self, run: &RunRequest) -> Option<String> {
        // Direct DOM targeting by ID
        if let Some(ref wanted_dom) = run.dom_id {
            // Check if DOM exists in any backend snapshot
            if self.backend_for_dom(wanted_dom).is_some() {
                return Some(wanted_dom.clone());
            }
            return None;
        }

        let parsed = if !run.target.is_empty() {
            crate::shared::target::parse(&run.target).ok()
        } else {
            None
        };

        let all_doms = self.all_doms();
        let mut best: Option<(String, usize)> = None;

        for (dom_id, dom) in &all_doms {
            if !dom.connected {
                continue;
            }

            // Session filter applies regardless of target — see the sibling
            // find_match_for_run: a session-pinned default-target run must not
            // route into another session's DOMs.
            if let Some(ref wanted) = run.session {
                if dom.session_guid.as_deref() != Some(wanted.as_str()) {
                    continue;
                }
            }

            if let Some(ref t) = parsed {
                let dom_mode = dom.mode.as_deref().unwrap_or("");
                let vm_dom = dom.dom_kind.as_deref().unwrap_or("");

                if t.mode.as_str() != dom_mode {
                    continue;
                }
                let target_dom = match t.dom_kind {
                    crate::shared::target::DomKind::Edit => "edit",
                    crate::shared::target::DomKind::Server => "server",
                    crate::shared::target::DomKind::Client => "client",
                };
                if target_dom != vm_dom {
                    continue;
                }
            }

            let count = dom.active_runs as usize;
            match &best {
                Some((_, best_count)) if count >= *best_count => {}
                _ => { best = Some((dom_id.clone(), count)); }
            }
        }

        best.map(|(dom_id, _)| dom_id)
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
                ..Default::default()
            }))),
            ..Default::default()
        }
    }

    /// Send a run command to a DOM and track it as active.
    fn dispatch_run(&mut self, dom_id: &str, run: RunRequest) {
        // Look up DOM's canonical studio_id from snapshot for log correlation.
        let studio = {
            let mut studio = None;
            for backend in self.backends.values() {
                let snap = backend.state_rx.borrow();
                if let Some(v) = snap.doms.iter().find(|v| v.dom_id == dom_id) {
                    studio = v.session_guid.clone();
                    break;
                }
            }
            studio
        };
        tracing::info!(
            id = run.execution_id.as_str(),
            dom = &dom_id[..8.min(dom_id.len())],
            target = run.target.as_str(),
            studio = studio.as_deref().map(|s| &s[..8.min(s.len())]).unwrap_or("-"),
            "dispatch"
        );
        let cmd = Self::build_run_command(&run);
        self.send_to_dom(dom_id, cmd);
        // An empty target on a non-pinned run took the routing default; record
        // the effective target. --dom-pinned runs keep it empty (DOM-native).
        let target = if run.target.is_empty() && run.dom_id.is_none() {
            "edit:plugin".to_string()
        } else {
            run.target.clone()
        };
        self.active_runs.insert(run.execution_id.clone(), ActiveRun {
            execution_id: run.execution_id.clone(),
            dom_id: dom_id.to_string(),
            target,
            client_tx: run.client_tx,
            state: ProcessState::PROCESS_STATE_RUNNING,
            profile: run.profile,
            created_at: run.created_at,
        });
    }

    /// Route a run to a matching DOM, or queue it as pending.
    pub fn route_or_queue(&mut self, run: RunRequest) -> bool {
        if let Some(dom_id) = self.find_match_for_run(&run) {
            self.dispatch_run(&dom_id, run);
            return true;
        }
        self.pending_runs.push(run);
        self.reconcile();
        false
    }

    /// Single entry point for all event-driven state reconciliation:
    /// re-route pending runs, drain runs targeting dead sessions, then
    /// push updated target_modes to studios' edit-DOM plugins.
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
            if let Some(dom_id) = self.find_match_for_run(run) {
                routed.push((i, dom_id));
            }
        }
        for (i, dom_id) in routed.into_iter().rev() {
            let run = self.pending_runs.remove(i);
            info!(id = run.execution_id.as_str(), dom = &dom_id[..8.min(dom_id.len())], "routed from queue");
            self.dispatch_run(&dom_id, run);
        }
    }

    /// Drain pending runs whose target session has no live DOM. Without this,
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
                b.state_rx.borrow().doms.iter().any(|v| {
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
                    id = run.execution_id.as_str(),
                    session = &scope_session[..8.min(scope_session.len())],
                    "pending run dropped: target session no longer alive",
                );
            }
        }
    }

    /// For each studio, compute the desired target mode from pending runs and
    /// broadcast SetTargetModeMsg to every DOM. The plugin on each DOM handles
    /// the target in a retry loop — edit DOM keeps trying the enter script,
    /// server DOM keeps trying EndTest — until its own mode matches (or the
    /// target changes). Backend just maintains the declarative state.
    pub fn derive_and_push_targets(&mut self) {
        let mut studio_doms: HashMap<String, Vec<String>> = HashMap::new();
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            for dom in &snap.doms {
                if !dom.connected { continue; }
                // Session-bearing DOMs group by session. Session-less DOMs —
                // manually-installed plugins report SESSION_GUID=nil — get their
                // own dom_id as a standalone key, so a session-less run (the common
                // `rodeo run --target X` / MCP run_code case) can still drive their
                // mode transition. Skipping them here meant the master never pushed
                // SetTargetMode to a hand-opened Studio, so auto-transition never
                // fired and the run hung in pending_runs forever.
                let key = match dom.session_guid.as_deref() {
                    Some(s) if !s.is_empty() => s.to_string(),
                    _ => dom.dom_id.clone(),
                };
                studio_doms.entry(key).or_default().push(dom.dom_id.clone());
            }
        }
        for doms in studio_doms.values_mut() { doms.sort(); }

        let mut derived: HashMap<String, String> = HashMap::new();
        for session in studio_doms.keys() { derived.insert(session.clone(), String::new()); }
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
                    for session in studio_doms.keys() {
                        derived.entry(session.clone()).and_modify(|v| {
                            if v.is_empty() { *v = mode.clone(); }
                        }).or_insert_with(|| mode.clone());
                    }
                }
            }
        }

        // Broadcast to every DOM in the studio when target or DOM set changed.
        let mut pushes: Vec<(String, String)> = Vec::new();
        let mut next_state: HashMap<String, (String, Vec<String>)> = HashMap::new();
        for (session, target) in &derived {
            let empty_doms: Vec<String> = Vec::new();
            let doms = studio_doms.get(session).unwrap_or(&empty_doms);
            let prev = self.target_modes.get(session);
            let changed = match prev {
                None => !target.is_empty(),
                Some((prev_target, prev_doms)) => prev_target != target || prev_doms != doms,
            };
            if changed {
                for dom_id in doms {
                    pushes.push((dom_id.clone(), target.clone()));
                }
            }
            next_state.insert(session.clone(), (target.clone(), doms.clone()));
        }
        self.target_modes = next_state;

        for (dom_id, target) in pushes {
            info!(dom = &dom_id[..8.min(dom_id.len())], target = target.as_str(), "push target_mode");
            let msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::SetTargetMode(Box::new(
                    rodeo_proto::SetTargetModeMsg { target_mode: target, ..Default::default() }
                ))),
                ..Default::default()
            };
            self.send_to_dom(&dom_id, msg);
        }
    }

    /// Explicitly set a studio's target mode (used by SetStudioMode RPC).
    /// Broadcasts to every DOM in the studio regardless of pending queue.
    pub fn set_target_mode(&mut self, session_guid: &str, mode: &str) {
        let mut doms: Vec<String> = {
            let mut found = Vec::new();
            for backend in self.backends.values() {
                let snap = backend.state_rx.borrow();
                for dom in &snap.doms {
                    if !dom.connected { continue; }
                    if dom.session_guid.as_deref() != Some(session_guid) { continue; }
                    found.push(dom.dom_id.clone());
                }
            }
            found
        };
        if doms.is_empty() { return; }
        doms.sort();

        self.target_modes.insert(session_guid.to_string(), (mode.to_string(), doms.clone()));
        info!(target = mode, session = &session_guid[..8.min(session_guid.len())], dom_count = doms.len(), "set target_mode explicitly");
        for dom_id in doms {
            let msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::SetTargetMode(Box::new(
                    rodeo_proto::SetTargetModeMsg { target_mode: mode.to_string(), ..Default::default() }
                ))),
                ..Default::default()
            };
            self.send_to_dom(&dom_id, msg);
        }
    }

    /// Forward a typed ClientRpcCall from a DOM's plugin to the run client.
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

        if is_profiled {
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
                info!(id = run.execution_id.as_str(), state = state_str, "completed");
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
    pub fn disconnect_run(&mut self, execution_id: &str) {
        info!(id = execution_id, "run client disconnected");
        self.pending_runs.retain(|r| r.execution_id != execution_id);

        if let Some(run) = self.active_runs.get(execution_id) {
            // Auto-kill: send kill command to the DOM
            let kill_msg = rodeo_proto::ServerMessage {
                msg: Some(rodeo_proto::server_message::Msg::Kill(Box::new(rodeo_proto::KillCommand {
                    execution_id: execution_id.to_string(),
                    ..Default::default()
                }))),
                ..Default::default()
            };
            let dom_id_owned = run.dom_id.clone();
            self.send_to_dom(&dom_id_owned, kill_msg);
        }
    }

    /// Get the mode for a specific session from backend snapshots.
    pub fn mode_for_session(&self, session_guid: &str) -> Option<String> {
        for backend in self.backends.values() {
            let snap = backend.state_rx.borrow();
            for dom in &snap.doms {
                if dom.session_guid.as_deref() == Some(session_guid) {
                    return dom.mode.clone();
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

        let mut doms = Vec::new();
        let mut instances: std::collections::HashMap<String, rodeo_proto::StudioInstanceState> =
            std::collections::HashMap::new();
        for (backend_id, backend) in &self.backends {
            let snap = backend.state_rx.borrow();
            for dom in &snap.doms {
                let mut dom = dom.clone();
                dom.backend_id = Some(backend_id.clone());
                doms.push(dom);
            }
            for inst in &snap.studio_instances {
                instances.insert(inst.session_guid.clone(), inst.clone());
            }
        }
        // Canonical studio-first state, grouped from the collected DOMs + lifecycle.
        let studios = build_studios(&doms, &instances);

        // Join each active run's dom_id against the studio-first state so the
        // process list carries where the run executes.
        let mut dom_owner: HashMap<&str, &rodeo_proto::StudioState> = HashMap::new();
        for st in &studios {
            for d in &st.doms {
                dom_owner.insert(d.dom_id.as_str(), st);
            }
        }

        let processes: Vec<rodeo_proto::ProcessInfo> = self.active_runs.values()
            .map(|r| {
                let owner = dom_owner.get(r.dom_id.as_str());
                rodeo_proto::ProcessInfo {
                    execution_id: r.execution_id.clone(),
                    state: match r.state {
                        ProcessState::PROCESS_STATE_RUNNING => "running",
                        ProcessState::PROCESS_STATE_DONE => "done",
                        ProcessState::PROCESS_STATE_ERROR => "error",
                        ProcessState::PROCESS_STATE_KILLED => "killed",
                        _ => "queued",
                    }.to_string(),
                    target: r.target.clone(),
                    context: identity_for_target(&r.target).to_string(),
                    studio_id: owner.map(|s| s.studio_id.clone()),
                    session_id: owner.and_then(|s| s.session_id.clone()),
                    dom_id: Some(r.dom_id.clone()),
                    created_at: r.created_at,
                    ..Default::default()
                }
            })
            // Queued runs aren't pinned to a DOM yet — only the request is known.
            .chain(self.pending_runs.iter().map(|r| rodeo_proto::ProcessInfo {
                execution_id: r.execution_id.clone(),
                state: "queued".to_string(),
                target: r.target.clone(),
                context: identity_for_target(&r.target).to_string(),
                created_at: r.created_at,
                ..Default::default()
            }))
            .collect();

        // `doms` is consumed only to derive `studios` (studio-first state); the
        // flat list is no longer part of the client-facing snapshot.
        let _ = &doms;
        rodeo_proto::RodeoSnapshot {
            backends,
            processes,
            studios,
            ..Default::default()
        }
    }
}

/// Derive the canonical studio-first state from the flat DOM list + per-Studio
/// lifecycle. DOMs are grouped by `session_guid` (a session_guid-less DOM — e.g. a
/// manually-installed plugin — becomes its own single-DOM studio keyed by domId).
fn build_studios(
    doms: &[rodeo_proto::DomSnapshot],
    instances: &std::collections::HashMap<String, rodeo_proto::StudioInstanceState>,
) -> Vec<rodeo_proto::StudioState> {
    // BTreeMap for a stable, deterministic studio ordering across snapshots.
    let mut groups: std::collections::BTreeMap<String, Vec<&rodeo_proto::DomSnapshot>> =
        std::collections::BTreeMap::new();
    for dom in doms {
        if !dom.connected {
            continue;
        }
        let key = dom
            .session_guid
            .clone()
            .unwrap_or_else(|| format!("dom:{}", dom.dom_id));
        groups.entry(key).or_default().push(dom);
    }

    groups
        .into_iter()
        .map(|(id, members)| {
            let edit = members.iter().copied().find(|v| v.dom_kind.as_deref() == Some("edit"));
            // Studio mode: a non-edit DOM's mode (run/test/play) if present, else
            // the edit DOM's mode.
            let active_mode_dom = members
                .iter()
                .copied()
                .find(|v| matches!(v.dom_kind.as_deref(), Some("server") | Some("client")));
            let studio_mode = active_mode_dom
                .or(edit)
                .and_then(|v| v.mode.clone())
                .unwrap_or_default();
            // Representative DOM for place/name/backend: prefer the edit DOM.
            let rep = edit.or_else(|| members.first().copied());
            let inst = instances.get(&id);
            // The group key is the launch session_guid unless this is a
            // session-less (manually-connected) studio keyed "dom:<id>".
            let session_id = if id.starts_with("dom:") { None } else { Some(id.clone()) };

            rodeo_proto::StudioState {
                studio_id: id.clone(),
                backend_id: rep.and_then(|v| v.backend_id.clone()).unwrap_or_default(),
                session_id,
                place_name: rep.and_then(|v| v.game_name.clone()).unwrap_or_default(),
                place_id: rep.and_then(|v| v.place_id).unwrap_or(0),
                status: inst
                    .map(|i| i.status.clone())
                    .unwrap_or_else(|| "connected".to_string()),
                studio_mode,
                edit_dom_id: edit.map(|v| v.dom_id.clone()),
                doms: members
                    .iter()
                    .map(|v| rodeo_proto::StudioDom {
                        dom_id: v.dom_id.clone(),
                        dom_kind: v.dom_kind.clone().unwrap_or_default(),
                        user_name: v.user_name.clone(),
                        user_id: v.user_id,
                        ..Default::default()
                    })
                    .collect(),
                ..Default::default()
            }
        })
        .collect()
}

/// The identity a run's code executes at, derived from its requested target.
/// Empty targets take the routing default (edit:plugin → plugin identity).
fn identity_for_target(target: &str) -> &'static str {
    if target.is_empty() {
        return "plugin";
    }
    match crate::shared::target::parse(target) {
        Ok(t) => t.identity.as_str(),
        Err(_) => "",
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
                            // StudioMCP requires a datamodel_type ("Edit" /
                            // "Server" / "Client") and only runs in types
                            // available in the Studio's current mode. The
                            // unifier self-branches on RunService, so fire it
                            // into every type; types not present in the current
                            // mode just error and are ignored. This is what
                            // distinguishes a play session's Server/Client DOMs
                            // (otherwise they stay unresolved and `test:*`
                            // targets never route to them).
                            for datamodel_type in ["Edit", "Server", "Client"] {
                                match mcp.execute_luau(&unify_code, datamodel_type).await {
                                    Ok(r) => tracing::debug!(datamodel_type, result = ?r, "execute_luau ok"),
                                    Err(e) => tracing::trace!(datamodel_type, "execute_luau skipped: {e}"),
                                }
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

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::sync::{mpsc, watch};

    fn edit_dom(dom_id: &str, session_guid: Option<&str>) -> rodeo_proto::DomSnapshot {
        rodeo_proto::DomSnapshot {
            dom_id: dom_id.to_string(),
            mode: Some("edit".to_string()),
            dom_kind: Some("edit".to_string()),
            session_guid: session_guid.map(|s| s.to_string()),
            connected: true,
            ..Default::default()
        }
    }

    fn queued_run(target: &str) -> (RunRequest, mpsc::UnboundedReceiver<ClientMsg>) {
        let (client_tx, client_rx) = mpsc::unbounded_channel();
        let run = RunRequest {
            execution_id: "exec-1".to_string(),
            script: String::new(),
            target: target.to_string(),
            session: None,
            dom_id: None,
            log_filter: rodeo_proto::LogFilter::default(),
            cache_requires: None,
            script_args: None,
            return_file: None,
            show_return: None,
            output_file: None,
            verbose: None,
            instance_path: None,
            script_path: None,
            profile: None,
            client_tx,
            state: rodeo_proto::ProcessState::PROCESS_STATE_QUEUED,
            created_at: 0.0,
        };
        (run, client_rx)
    }

    fn state_with_edit_dom(
        dom_id: &str,
        session_guid: Option<&str>,
    ) -> (MasterState, mpsc::UnboundedReceiver<rodeo_proto::MasterMessage>) {
        let mut state = MasterState::new("master-test".to_string());
        let (backend_tx, backend_rx) = mpsc::unbounded_channel();
        let (state_tx, state_rx) = watch::channel(rodeo_proto::StateSnapshot {
            doms: vec![edit_dom(dom_id, session_guid)],
            ..Default::default()
        });
        state.backends.insert(
            "backend-1".to_string(),
            grpc::BackendConnection {
                id: "backend-1".to_string(),
                kind: "studio".to_string(),
                name: "test-studio".to_string(),
                tx: backend_tx,
                state_tx,
                state_rx,
            },
        );
        (state, backend_rx)
    }

    // Regression: a manually-installed plugin reports SESSION_GUID=nil, so its
    // edit DOM registers with no session_guid. derive_and_push_targets used to
    // skip session-less DOMs entirely, so the master never pushed SetTargetMode
    // to a hand-opened Studio — auto-transition never fired and the run hung in
    // pending_runs forever. A session-less edit DOM must still be driven for a
    // session-less (`session: None`) run.
    #[test]
    fn session_less_edit_dom_is_driven_for_a_session_less_run() {
        let (mut state, mut backend_rx) = state_with_edit_dom("edit-dom", None);
        let (run, _client_rx) = queued_run("test:server");
        state.pending_runs.push(run);

        state.derive_and_push_targets();

        // Session-less DOM is keyed by its own dom_id and gets the "test" target.
        assert_eq!(
            state.target_modes.get("edit-dom"),
            Some(&("test".to_string(), vec!["edit-dom".to_string()])),
            "session-less edit DOM must be included in target derivation"
        );
        // And an actual SetTargetMode push must be dispatched to its backend.
        assert!(backend_rx.try_recv().is_ok(), "a SetTargetMode push must be sent to the DOM");
    }

    // Control: a session-bearing edit DOM keeps being keyed by its session.
    #[test]
    fn session_bearing_edit_dom_is_driven_by_session() {
        let (mut state, _backend_rx) = state_with_edit_dom("edit-dom", Some("sess-A"));
        let (run, _client_rx) = queued_run("test:server");
        state.pending_runs.push(run);

        state.derive_and_push_targets();

        assert_eq!(
            state.target_modes.get("sess-A"),
            Some(&("test".to_string(), vec!["edit-dom".to_string()])),
            "session-bearing DOM is keyed by its session_guid"
        );
    }
}
