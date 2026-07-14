use std::sync::Arc;

use crate::proto;
use crate::run::{self, RunCodeOpts, RunResult, RunStream};
use crate::transport::Transport;

/// A handle to a single DOM inside a Studio / game server / player.
/// Stateless w.r.t. the master — property reads are from the snapshot; `runCode`
/// opens a fresh bidi stream on each call.
#[derive(Clone)]
pub struct Dom {
    pub dom_id: String,
    pub backend_id: String,
    pub mode: String,
    pub dom_kind: String,
    pub session_guid: Option<String>,
    pub place_id: i64,
    pub game_name: String,
    pub connected: bool,
    pub active_runs: u32,
    /// Player name for client DOMs (from the studio-first state). None otherwise.
    pub user_name: Option<String>,
    /// Player userId for client DOMs. None otherwise.
    pub user_id: Option<i64>,
    pub(crate) transport: Arc<Transport>,
}

impl Dom {
    /// Build a DOM handle from the canonical studio-first state. DOM-level fields
    /// (`dom_id`, `dom_kind`, `user_name`/`user_id`) come from the `StudioDom`;
    /// the rest (`backend_id`, `session_guid`, place) come from the parent
    /// `StudioState`. The edit DOM's mode is always "edit"; non-edit DOMs share
    /// the studio's active mode (run/test/play).
    pub(crate) fn from_studio_dom(
        studio: &proto::StudioState,
        v: &proto::StudioDom,
        transport: Arc<Transport>,
    ) -> Self {
        let mode = if v.dom_kind == "edit" { "edit".to_string() } else { studio.studio_mode.clone() };
        Self {
            dom_id: v.dom_id.clone(),
            backend_id: studio.backend_id.clone(),
            mode,
            dom_kind: v.dom_kind.clone(),
            session_guid: studio.session_id.clone(),
            place_id: studio.place_id,
            game_name: studio.place_name.clone(),
            connected: true,
            active_runs: 0,
            user_name: v.user_name.clone(),
            user_id: v.user_id,
            transport,
        }
    }

    /// Execute code on THIS DOM, buffering output and returning the final
    /// RunResult. A Dom handle always pins — no routing happens. Only
    /// `opts.context` applies; routing fields (`mode`/`dom_kind`/`clients`)
    /// are rejected: session-scoped routing lives on `Studio::run_code`.
    pub async fn run_code(&self, opts: RunCodeOpts) -> anyhow::Result<RunResult> {
        self.reject_routing_opts(&opts)?;
        run::run_buffered(self.transport.clone(), &self.dom_id, self.session_guid.clone(), opts)
            .await
    }

    /// Execute code with streaming output events.
    /// Caller drives the returned `RunStream` to receive output chunks / file
    /// chunks / completion events incrementally.
    pub async fn run_code_stream(&self, opts: RunCodeOpts) -> anyhow::Result<RunStream> {
        self.reject_routing_opts(&opts)?;
        run::run_stream(self.transport.clone(), &self.dom_id, self.session_guid.clone(), opts)
            .await
    }

    fn reject_routing_opts(&self, opts: &RunCodeOpts) -> anyhow::Result<()> {
        if opts.mode.is_some() || opts.dom_kind.is_some() || opts.clients.is_some() {
            anyhow::bail!(
                "mode/dom/clients don't apply to a pinned DOM — use Studio::run_code for session-scoped routing"
            );
        }
        Ok(())
    }
}
