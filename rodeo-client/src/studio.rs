use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::{anyhow, bail, Result};

use crate::proto;
use crate::transport::Transport;
use crate::vm::Vm;

const VM_WAIT_TIMEOUT_MS: u64 = 60_000;
const VM_POLL_INTERVAL_MS: u64 = 200;


// ---------------------------------------------------------------------------
// StudioBackend
// ---------------------------------------------------------------------------

/// Options for `StudioBackend::open` — empty place, edit mode.
#[derive(Default, Clone)]
pub struct OpenOpts {
    pub fflags: Vec<String>,
    pub background: bool,
    pub profile: bool,
    pub save: Option<String>,
    pub detached: bool,
    pub fflag_file: Option<String>,
    pub no_hud: bool,
}

/// Options for `StudioBackend::open_place` — open by place ID.
#[derive(Clone)]
pub struct OpenPlaceOpts {
    pub place_id: u64,
    pub fflags: Vec<String>,
    pub background: bool,
    pub profile: bool,
    pub save: Option<String>,
    pub detached: bool,
    pub fflag_file: Option<String>,
    pub no_hud: bool,
}

/// Options for `StudioBackend::open_file` — open by file path.
#[derive(Clone)]
pub struct OpenFileOpts {
    pub path: String,
    pub fflags: Vec<String>,
    pub background: bool,
    pub profile: bool,
    pub save: Option<String>,
    pub detached: bool,
    pub fflag_file: Option<String>,
    pub no_hud: bool,
}

#[derive(Clone)]
pub struct StudioBackend {
    pub id: String,
    pub name: String,
    transport: Arc<Transport>,
}

impl StudioBackend {
    pub(crate) fn new(info: proto::BackendInfo, transport: Arc<Transport>) -> Self {
        Self { id: info.id, name: info.name, transport }
    }

    pub async fn open(&self, opts: OpenOpts) -> Result<Studio> {
        self.launch(proto::LaunchStudioRequest {
            backend: self.id.clone(),
            fflags: opts.fflags,
            background: opts.background,
            detached: opts.detached,
            profile: opts.profile,
            save_path: opts.save,
            fflag_file: opts.fflag_file,
            no_hud: opts.no_hud,
            ..Default::default()
        }).await
    }

    pub async fn open_place(&self, opts: OpenPlaceOpts) -> Result<Studio> {
        self.launch(proto::LaunchStudioRequest {
            backend: self.id.clone(),
            place_id: Some(opts.place_id),
            fflags: opts.fflags,
            background: opts.background,
            detached: opts.detached,
            profile: opts.profile,
            save_path: opts.save,
            fflag_file: opts.fflag_file,
            no_hud: opts.no_hud,
            ..Default::default()
        }).await
    }

    pub async fn open_file(&self, opts: OpenFileOpts) -> Result<Studio> {
        self.launch(proto::LaunchStudioRequest {
            backend: self.id.clone(),
            place_file: Some(opts.path),
            fflags: opts.fflags,
            background: opts.background,
            detached: opts.detached,
            profile: opts.profile,
            save_path: opts.save,
            fflag_file: opts.fflag_file,
            no_hud: opts.no_hud,
            ..Default::default()
        }).await
    }

    /// Low-level launch — use when building the LaunchStudioRequest outside the
    /// typed OpenOpts/OpenPlaceOpts/OpenFileOpts helpers (e.g. for the CLI
    /// commands/run.rs orchestration).
    pub async fn launch(&self, req: proto::LaunchStudioRequest) -> Result<Studio> {
        let mut stream = self.transport.master()
            .launch_studio(req)
            .await
            .map_err(|e| anyhow!("failed to launch studio: {e}"))?;
        while let Ok(Some(view)) = stream.message().await {
            let event = view.to_owned_message();
            match event.event {
                Some(proto::launch_studio_event::Event::Ready(ready)) => {
                    let session_guid = ready.session_guid.clone();
                    let backend_id = ready.backend_id.clone();
                    let mut studio = Studio {
                        session_guid: session_guid.clone(),
                        backend_id,
                        transport: self.transport.clone(),
                        edit_vm: None,
                        server_vm: None,
                        client_vm: None,
                    };
                    // Invariant: when open resolves, the edit VM is connected
                    // under this Studio instance (waited via the canonical
                    // studio-first state).
                    let inst = studio.wait_for_instance(
                        |s| s.vms.iter().any(|v| v.dom == "edit"),
                        VM_WAIT_TIMEOUT_MS,
                    ).await?;
                    studio.edit_vm = studio.vm_by_dom(&inst, "edit");
                    return Ok(studio);
                }
                Some(proto::launch_studio_event::Event::Error(err)) => {
                    bail!("studio launch failed: {}", err.message);
                }
                _ => {}
            }
        }
        bail!("launch stream ended without ready event")
    }
}

// ---------------------------------------------------------------------------
// Studio
// ---------------------------------------------------------------------------

pub struct Studio {
    pub session_guid: String,
    pub backend_id: String,
    transport: Arc<Transport>,
    /// Populated when open resolves.
    pub edit_vm: Option<Vm>,
    /// Populated by `set_mode("run"/"test"/"play")`.
    pub server_vm: Option<Vm>,
    /// Populated by `set_mode("test"/"play")`.
    pub client_vm: Option<Vm>,
}

impl Studio {
    /// Returns the edit VM, panicking if `open` never resolved it (impossible
    /// unless constructed by hand). Matches the TS `editVm!` non-null assert.
    pub fn edit_vm(&self) -> &Vm {
        self.edit_vm.as_ref().expect("edit_vm must be set after open")
    }

    /// This Studio's canonical state from the master's studio-first snapshot
    /// (by `session_guid`), or None if not yet present.
    pub async fn instance_state(&self) -> Result<Option<proto::StudioState>> {
        let state = self.transport.master()
            .get_state(proto::GetStateRequest::default())
            .await
            .map_err(|e| anyhow!("get_state failed: {e}"))?
            .into_owned();
        Ok(state.studios.into_iter().find(|s| s.id == self.session_guid))
    }

    /// Poll the canonical studio-first state until this Studio satisfies `pred`.
    /// Replaces per-VM polling — callers express the whole-instance condition
    /// they expect (e.g. "a server VM and N client VMs are present").
    pub async fn wait_for_instance<F>(&self, pred: F, timeout_ms: u64) -> Result<proto::StudioState>
    where
        F: Fn(&proto::StudioState) -> bool,
    {
        let deadline = Instant::now() + Duration::from_millis(timeout_ms);
        loop {
            if let Some(s) = self.instance_state().await? {
                if pred(&s) {
                    return Ok(s);
                }
            }
            if Instant::now() >= deadline {
                bail!("timed out waiting for studio instance {} to reach expected state", self.session_guid);
            }
            tokio::time::sleep(Duration::from_millis(VM_POLL_INTERVAL_MS)).await;
        }
    }

    /// Resolve the first VM in `studio` with the given `dom` to a VM handle.
    pub(crate) fn vm_by_dom(&self, studio: &proto::StudioState, dom: &str) -> Option<Vm> {
        studio.vms.iter()
            .find(|v| v.dom == dom)
            .map(|v| Vm::from_studio_vm(studio, v, self.transport.clone()))
    }

    pub async fn set_mode(&mut self, mode: &str) -> Result<()> {
        self.transport.master()
            .set_studio_mode(proto::SetStudioModeRequest {
                session_guid: self.session_guid.clone(),
                mode: mode.to_string(),
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("set_studio_mode failed: {e}"))?;

        if mode == "edit" {
            self.server_vm = None;
            self.client_vm = None;
            return Ok(());
        }

        // Wait on the canonical studio state for the expected member VMs to
        // appear. We gate on `dom` presence rather than per-VM mode strings —
        // the studio reaching the requested config is what matters, and the
        // test/play distinction is a post-hoc reconciliation detail.
        let want_client = mode == "test" || mode == "play";
        let inst = self.wait_for_instance(
            move |s| {
                let has_server = s.vms.iter().any(|v| v.dom == "server");
                let has_client = !want_client || s.vms.iter().any(|v| v.dom == "client");
                has_server && has_client
            },
            VM_WAIT_TIMEOUT_MS,
        ).await?;

        self.server_vm = self.vm_by_dom(&inst, "server");
        self.client_vm = if want_client { self.vm_by_dom(&inst, "client") } else { None };
        Ok(())
    }

    pub async fn get_mode(&self) -> Result<String> {
        let resp = self.transport.master()
            .set_studio_mode(proto::SetStudioModeRequest {
                session_guid: self.session_guid.clone(),
                mode: String::new(),
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("get_mode failed: {e}"))?
            .into_owned();
        Ok(resp.mode)
    }

    pub async fn save(&self) -> Result<proto::SavePlaceResponse> {
        let resp = self.transport.master()
            .save_place(proto::SavePlaceRequest {
                backend: Some(String::new()),
                session_guid: Some(self.session_guid.clone()),
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("save failed: {e}"))?
            .into_owned();
        if !resp.saved {
            bail!("save failed: {}", resp.error.as_deref().unwrap_or(""));
        }
        Ok(resp)
    }

    pub async fn close(&self) -> Result<()> {
        let mut stream = self.transport.master()
            .close_studio(proto::CloseStudioRequest {
                session_guid: self.session_guid.clone(),
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("close failed: {e}"))?;
        while let Ok(Some(view)) = stream.message().await {
            let event = view.to_owned_message();
            if let Some(proto::close_studio_event::Event::Closed(_)) = event.event {
                return Ok(());
            }
        }
        Ok(())
    }

    pub async fn get_vms(&self) -> Result<Vec<Vm>> {
        match self.instance_state().await? {
            Some(s) => Ok(s.vms.iter()
                .map(|v| Vm::from_studio_vm(&s, v, self.transport.clone()))
                .collect()),
            None => Ok(Vec::new()),
        }
    }

    /// Start an in-Studio multiplayer test via
    /// `StudioTestService:ExecuteMultiplayerTestAsync` with `num_players` client
    /// DataModels. Runs the start snippet on the edit VM (fire-and-forget — the
    /// API yields for the session's life), then waits on the canonical studio
    /// state for the server + N client VMs to register.
    pub async fn start_multiplayer_test(&self, num_players: u32) -> Result<MultiplayerTest> {
        let edit = self.edit_vm.as_ref()
            .ok_or_else(|| anyhow!("start_multiplayer_test requires an open edit Studio"))?;

        let snippet = format!(
            "local sts = game:GetService(\"StudioTestService\")\n\
             task.spawn(function()\n\
             \tsts:ExecuteMultiplayerTestAsync({num_players}, {{ rodeo = true }})\n\
             end)\n\
             return \"started\""
        );
        edit.run_code(crate::run::RunCodeOpts { source: snippet, ..Default::default() }).await?;

        let n = num_players as usize;
        let inst = self.wait_for_instance(
            move |s| {
                s.vms.iter().any(|v| v.dom == "server")
                    && s.vms.iter().filter(|v| v.dom == "client").count() == n
            },
            VM_WAIT_TIMEOUT_MS,
        ).await?;

        let server = self.vm_by_dom(&inst, "server")
            .ok_or_else(|| anyhow!("multiplayer test started but no server VM appeared"))?;
        let clients: Vec<Vm> = inst.vms.iter()
            .filter(|v| v.dom == "client")
            .map(|v| Vm::from_studio_vm(&inst, v, self.transport.clone()))
            .collect();

        Ok(MultiplayerTest {
            server,
            clients,
            session_guid: self.session_guid.clone(),
            transport: self.transport.clone(),
        })
    }
}

// ---------------------------------------------------------------------------
// MultiplayerTest — a running in-Studio multiplayer test (one server DataModel +
// N client DataModels, all under the edit Studio's session). Control is just
// `run_code` against the right VM (StudioTestService:AddPlayers/EndTest/LeaveTest).
// ---------------------------------------------------------------------------

pub struct MultiplayerTest {
    pub server: Vm,
    pub clients: Vec<Vm>,
    session_guid: String,
    transport: Arc<Transport>,
}

impl MultiplayerTest {
    pub fn server(&self) -> &Vm { &self.server }
    pub fn clients(&self) -> &[Vm] { &self.clients }

    /// Connect one more client DataModel (`StudioTestService:AddPlayers(1)` on
    /// the server), wait for it to register, and return its Vm handle.
    pub async fn connect_client(&mut self) -> Result<Vm> {
        let known: std::collections::HashSet<String> =
            self.clients.iter().map(|v| v.vm_id.clone()).collect();
        self.server.run_code(crate::run::RunCodeOpts {
            source: "game:GetService(\"StudioTestService\"):AddPlayers(1)\nreturn true".to_string(),
            ..Default::default()
        }).await?;
        let known_pred = known.clone();
        let inst = self.wait_for_instance(move |s| {
            s.vms.iter().any(|v| v.dom == "client" && !known_pred.contains(&v.vm_id))
        }).await?;
        self.clients = inst.vms.iter()
            .filter(|v| v.dom == "client")
            .map(|v| Vm::from_studio_vm(&inst, v, self.transport.clone()))
            .collect();
        self.clients.iter()
            .find(|v| !known.contains(&v.vm_id))
            .cloned()
            .ok_or_else(|| anyhow!("new client VM did not appear in studio state"))
    }

    /// Disconnect one client (`StudioTestService:LeaveTest` on that client VM),
    /// identified by its vmId.
    pub async fn disconnect_client(&mut self, vm_id: &str) -> Result<()> {
        let index = self.clients.iter().position(|v| v.vm_id == vm_id)
            .ok_or_else(|| anyhow!("no client with vmId {vm_id} in this test"))?;
        self.clients[index].run_code(crate::run::RunCodeOpts {
            source: "local s = game:GetService(\"StudioTestService\")\n\
                     if s:CanLeaveTest() then s:LeaveTest() end\nreturn true".to_string(),
            ..Default::default()
        }).await?;
        self.clients.remove(index);
        Ok(())
    }

    /// End the whole session (`StudioTestService:EndTest` on the server).
    pub async fn close(&self) -> Result<()> {
        self.server.run_code(crate::run::RunCodeOpts {
            source: "game:GetService(\"StudioTestService\"):EndTest(\"end\")\nreturn true".to_string(),
            ..Default::default()
        }).await?;
        Ok(())
    }

    /// Poll this test's studio (by session_guid) until `pred` holds.
    async fn wait_for_instance<F>(&self, pred: F) -> Result<proto::StudioState>
    where
        F: Fn(&proto::StudioState) -> bool,
    {
        let deadline = Instant::now() + Duration::from_millis(VM_WAIT_TIMEOUT_MS);
        loop {
            let state = self.transport.master()
                .get_state(proto::GetStateRequest::default())
                .await
                .map_err(|e| anyhow!("get_state failed: {e}"))?
                .into_owned();
            if let Some(s) = state.studios.into_iter().find(|s| s.id == self.session_guid) {
                if pred(&s) {
                    return Ok(s);
                }
            }
            if Instant::now() >= deadline {
                bail!("timed out waiting for multiplayer test state");
            }
            tokio::time::sleep(Duration::from_millis(VM_POLL_INTERVAL_MS)).await;
        }
    }
}

