use std::collections::HashMap;
use tokio::sync::mpsc;

use rodeo_proto::{self as proto, ProcessState, StudioStateMsg};

/// A script execution request — single source of truth for a run's lifecycle.
#[derive(Debug, Clone)]
pub struct RunRequest {
    pub execution_id: String,
    pub script: String,
    pub target: String,
    /// Session filter — matches a VM's master-minted `session_guid`. Used by
    /// Vm-scoped callers (TS `Vm.runCode`) to narrow target-based search to a
    /// specific Studio launch.
    pub session: Option<String>,
    /// Direct VM targeting (bypasses mode/dom matching)
    pub vm_id: Option<String>,
    pub log_filter: proto::LogFilter,
    pub cache_requires: Option<bool>,
    pub script_args: Option<Vec<String>>,
    pub return_file: Option<String>,
    pub show_return: Option<bool>,
    pub output_file: Option<String>,
    pub verbose: Option<bool>,
    pub instance_path: Option<String>,
    pub script_path: Option<String>,
    /// Whether this run has profiling enabled
    pub profile: Option<bool>,
    /// Channel to send output back to the run client
    pub client_tx: mpsc::UnboundedSender<crate::master::ClientMsg>,

    // Process metadata
    pub state: ProcessState,
    pub created_at: f64,
}

/// Produce a human-readable diff between two StudioStateMsg snapshots.
/// Returns None if nothing meaningful changed.
pub fn diff_state(new: &StudioStateMsg, old: &StudioStateMsg) -> Option<String> {
    let mut changes = Vec::new();

    fn opt(s: &str) -> &str { if s.is_empty() { "?" } else { s } }

    if new.mode != old.mode {
        changes.push(format!("mode: {} → {}", opt(&old.mode), opt(&new.mode)));
    }
    if new.dom != old.dom {
        changes.push(format!("dom: {} → {}", opt(&old.dom), opt(&new.dom)));
    }
    if new.mcp_studio_id != old.mcp_studio_id {
        let short = |s: &Option<String>| s.as_deref().map(|v| &v[..8.min(v.len())]).unwrap_or("none").to_string();
        changes.push(format!("mcp_studio_id: {} → {}", short(&old.mcp_studio_id), short(&new.mcp_studio_id)));
    }
    if new.is_server != old.is_server {
        changes.push(format!("is_server: {} → {}", old.is_server, new.is_server));
    }
    if new.is_client != old.is_client {
        changes.push(format!("is_client: {} → {}", old.is_client, new.is_client));
    }
    if new.is_running != old.is_running {
        changes.push(format!("is_running: {} → {}", old.is_running, new.is_running));
    }
    if new.is_edit != old.is_edit {
        changes.push(format!("is_edit: {} → {}", old.is_edit, new.is_edit));
    }

    if changes.is_empty() { None } else { Some(changes.join(", ")) }
}

/// A Studio instance, derived from connected VMs grouped by session_guid.
#[derive(Debug, Clone, serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StudioInstance {
    /// Master-minted session identity. Same value as the `session_guid` stamped
    /// on each VM belonging to this Studio.
    pub session_guid: String,
    /// "edit" | "run" | "test" | "play"
    pub mode: String,
    pub name: String,
    pub place_id: i64,
    pub universe_id: i64,
    pub edit_vm: Option<String>,
    pub server_vm: Option<String>,
    pub client_vms: Vec<String>,
}

/// Per-VM connection state, keyed by vmId.
pub struct VmConnection {
    #[allow(dead_code)]
    pub vm_id: String,
    pub studio_tx: mpsc::UnboundedSender<String>,
    pub connected: bool,
    pub active_runs: HashMap<String, RunRequest>,
    /// Canonicalized state from the plugin (updated via studio_state messages)
    pub state: Option<StudioStateMsg>,
    /// Master-minted session identity, stamped on the VM when the plugin
    /// connects to a launched `StudioInstance`. This is the single routing key
    /// across master, backends, and clients (replaces the old dual
    /// `canonical_studio_id` + `session_uid` identities).
    pub session_guid: Option<String>,
}

impl VmConnection {
    pub fn new(vm_id: String, studio_tx: mpsc::UnboundedSender<String>) -> Self {
        Self {
            vm_id,
            studio_tx,
            connected: true,
            active_runs: HashMap::new(),
            state: None,
            session_guid: None,
        }
    }

    /// Update the VM state from a studio_state message.
    /// Returns a diff string if anything meaningful changed.
    pub fn update_state(&mut self, new_state: StudioStateMsg) -> Option<String> {
        let diff = self.state.as_ref().and_then(|old| diff_state(&new_state, old));
        self.state = Some(new_state);
        diff
    }

    /// Start a run on this VM
    pub fn start_run(&mut self, mut run: RunRequest) {
        let identity = if run.target.is_empty() {
            "plugin".to_string()
        } else {
            crate::shared::target::parse(&run.target)
                .map(|t| t.identity.as_str().to_string())
                .unwrap_or_else(|_| "plugin".to_string())
        };

        let run_cmd = proto::ServerMessage {
            msg: Some(proto::server_message::Msg::Run(Box::new(
                proto::RunCommand {
                    execution_id: run.execution_id.clone(),
                    script: run.script.clone(),
                    target: identity,
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
                },
            ))),
            ..Default::default()
        };

        let msg = serde_json::to_string(&run_cmd).unwrap();

        tracing::info!(id = run.execution_id.as_str(), target = run.target.as_str(), "executing");

        run.state = ProcessState::PROCESS_STATE_RUNNING;
        let _ = self.studio_tx.send(msg);
        self.active_runs
            .insert(run.execution_id.clone(), run);
    }

    /// Complete a run, removing it from active_runs and returning it.
    pub fn complete_run(&mut self, execution_id: &str, state: &ProcessState) -> Option<RunRequest> {
        if let Some(run) = self.active_runs.remove(execution_id) {
            tracing::info!(id = execution_id, state = crate::master::grpc::process_state_str(state), "completed");
            Some(run)
        } else {
            None
        }
    }

    /// Mark a run as done without removing it (keeps client_tx alive for file transfers).
    /// Returns true if the run was found and marked.
    pub fn mark_done(&mut self, execution_id: &str, state: &ProcessState) -> bool {
        if let Some(run) = self.active_runs.get_mut(execution_id) {
            tracing::info!(id = execution_id, state = crate::master::grpc::process_state_str(state), "completed (draining files)");
            run.state = state.clone();
            true
        } else {
            false
        }
    }

    /// Forward a typed RPC call to the run client. Returns true if the execution was found.
    pub fn forward_rpc_call(&self, execution_id: &str, call: rodeo_proto::runtime_types::ClientRpcCall) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(crate::master::ClientMsg::RpcCall(Box::new(call)));
            true
        } else {
            false
        }
    }

    /// Forward a typed ExecutionDone to the run client.
    pub fn forward_execution_done(&self, execution_id: &str, done: rodeo_proto::ExecutionDone) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(crate::master::ClientMsg::ExecutionDone(Box::new(done)));
            true
        } else {
            false
        }
    }

    /// Forward a typed ExecutionKilled to the run client.
    pub fn forward_execution_killed(&self, execution_id: &str, killed: rodeo_proto::ExecutionKilled) -> bool {
        if let Some(run) = self.active_runs.get(execution_id) {
            let _ = run.client_tx.send(crate::master::ClientMsg::ExecutionKilled(Box::new(killed)));
            true
        } else {
            false
        }
    }

    /// Handle Studio disconnection
    pub fn disconnect(&mut self) {
        self.connected = false;

        for (eid, run) in &self.active_runs {
            let _ = run.client_tx.send(crate::master::ClientMsg::Disconnect(format!("studio disconnected (eid={eid})")));
        }

        self.active_runs.clear();
    }

    pub fn active_count(&self) -> usize {
        self.active_runs.len()
    }

    /// Get the mode from VM state, if available.
    pub fn mode(&self) -> Option<&str> {
        self.state.as_ref().map(|s| if s.mode.is_empty() { None } else { Some(s.mode.as_str()) }).flatten()
    }

    /// Get the dom from VM state, if available.
    pub fn dom(&self) -> Option<&str> {
        self.state.as_ref().map(|s| if s.dom.is_empty() { None } else { Some(s.dom.as_str()) }).flatten()
    }
}
