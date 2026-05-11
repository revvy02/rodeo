use std::sync::Arc;

use crate::proto;
use crate::run::{self, RunCodeOpts, RunResult, RunStream};
use crate::transport::Transport;

/// A handle to a single VM inside a Studio / game server / player.
/// Stateless w.r.t. the master — property reads are from the snapshot; `runCode`
/// opens a fresh bidi stream on each call.
#[derive(Clone)]
pub struct Vm {
    pub vm_id: String,
    pub backend_id: String,
    pub mode: String,
    pub dom: String,
    pub session_guid: Option<String>,
    pub place_id: i64,
    pub game_name: String,
    pub connected: bool,
    pub active_runs: u32,
    pub(crate) transport: Arc<Transport>,
}

impl Vm {
    pub(crate) fn from_snapshot(snap: proto::VmSnapshot, transport: Arc<Transport>) -> Self {
        Self {
            vm_id: snap.vm_id,
            backend_id: snap.backend_id.unwrap_or_default(),
            mode: snap.mode.unwrap_or_default(),
            dom: snap.dom.unwrap_or_default(),
            session_guid: snap.session_guid,
            place_id: snap.place_id.unwrap_or(0),
            game_name: snap.game_name.unwrap_or_default(),
            connected: snap.connected,
            active_runs: snap.active_runs,
            transport,
        }
    }

    /// Execute code, buffering output and returning the final RunResult.
    ///
    /// If `opts.target` is set and non-empty, this Vm handle becomes a
    /// *session* anchor (not a VM selector): the server routes by target
    /// within this Studio's session. Without this, `editVm.runCode({
    /// target: "run:server" })` would pin execution to the edit VM and the
    /// server's auto-transition machinery (edit → run) never fires.
    pub async fn run_code(&self, opts: RunCodeOpts) -> anyhow::Result<RunResult> {
        let (vm_id, session) = self.resolve_routing(&opts);
        run::run_buffered(self.transport.clone(), vm_id, session, opts).await
    }

    /// Execute code with streaming output events.
    /// Caller drives the returned `RunStream` to receive output chunks / file
    /// chunks / completion events incrementally.
    pub async fn run_code_stream(&self, opts: RunCodeOpts) -> anyhow::Result<RunStream> {
        let (vm_id, session) = self.resolve_routing(&opts);
        run::run_stream(self.transport.clone(), vm_id, session, opts).await
    }

    /// Decide whether this call pins to a specific VM or defers routing to
    /// the server via `target` (see `run_code` for rationale). Returned
    /// `vm_id` is `""` in the deferred case so the submit protocol treats
    /// it as "server-routed".
    fn resolve_routing(&self, opts: &RunCodeOpts) -> (&str, Option<String>) {
        let has_target = opts.target.as_deref().map(|t| !t.is_empty()).unwrap_or(false);
        if has_target {
            ("", self.session_guid.clone())
        } else {
            (&self.vm_id, self.session_guid.clone())
        }
    }
}
