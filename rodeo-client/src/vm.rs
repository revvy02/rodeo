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
    /// Player name for client VMs (from the studio-first state). None otherwise.
    pub client_name: Option<String>,
    pub(crate) transport: Arc<Transport>,
}

impl Vm {
    /// Build a VM handle from the canonical studio-first state. VM-level fields
    /// (`vm_id`, `dom`, `client_name`) come from the `StudioVm`; the rest
    /// (`backend_id`, `session_guid`, place, name) come from the parent
    /// `StudioState`. The edit VM's mode is always "edit"; non-edit VMs share
    /// the studio's active mode (run/test/play).
    pub(crate) fn from_studio_vm(
        studio: &proto::StudioState,
        v: &proto::StudioVm,
        transport: Arc<Transport>,
    ) -> Self {
        // Synthetic single-VM studios (no real session) use a "vm:" id prefix.
        let session_guid = if studio.id.starts_with("vm:") {
            None
        } else {
            Some(studio.id.clone())
        };
        let mode = if v.dom == "edit" { "edit".to_string() } else { studio.mode.clone() };
        Self {
            vm_id: v.vm_id.clone(),
            backend_id: studio.backend_id.clone(),
            mode,
            dom: v.dom.clone(),
            session_guid,
            place_id: studio.place_id,
            game_name: studio.name.clone(),
            connected: true,
            active_runs: 0,
            client_name: v.client_name.clone(),
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
