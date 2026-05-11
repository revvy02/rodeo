use std::sync::Arc;
use std::time::{Duration, Instant};

use anyhow::{anyhow, bail, Result};

use crate::proto;
use crate::transport::Transport;
use crate::vm::Vm;

const VM_WAIT_TIMEOUT_MS: u64 = 60_000;
const VM_POLL_INTERVAL_MS: u64 = 200;

/// Poll master state until a connected VM matching `pred` appears. Free
/// helper so both `Studio::wait_for_vm` and `StudioBackend::start_multiplayer_test`
/// can use it without duplicating the poll loop.
pub(crate) async fn wait_for_vm_on<F>(transport: &Arc<Transport>, pred: F, timeout_ms: u64) -> Result<Vm>
where
    F: Fn(&Vm) -> bool,
{
    let deadline = Instant::now() + Duration::from_millis(timeout_ms);
    loop {
        let state = transport.master()
            .get_state(proto::GetStateRequest::default())
            .await
            .map_err(|e| anyhow!("get_state failed while polling for VM: {e}"))?
            .into_owned();
        for snap in state.vms.into_iter() {
            let vm = Vm::from_snapshot(snap, transport.clone());
            if vm.connected && pred(&vm) {
                return Ok(vm);
            }
        }
        if Instant::now() >= deadline {
            bail!("timed out waiting for VM to register");
        }
        tokio::time::sleep(Duration::from_millis(VM_POLL_INTERVAL_MS)).await;
    }
}

// ---------------------------------------------------------------------------
// StudioBackend
// ---------------------------------------------------------------------------

/// Options for `StudioBackend::open` — empty place, edit mode.
#[derive(Default, Clone)]
pub struct OpenOpts {
    pub fflags: Vec<String>,
    pub background: bool,
    pub profile: bool,
    pub logs: Option<String>,
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
    pub logs: Option<String>,
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
    pub logs: Option<String>,
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
            logs_dir: opts.logs,
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
            logs_dir: opts.logs,
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
            logs_dir: opts.logs,
            no_hud: opts.no_hud,
            ..Default::default()
        }).await
    }

    /// Launch an isolated multiplayer-test server (Studio `-task StartServer`).
    /// The MP server is OS-isolated: its own process, its own session_guid
    /// (minted by master), parented to the rodeo CLI — **no edit Studio
    /// required**.
    ///
    /// Reads the streaming `launch_multiplayer_test_server` events: returns Ok
    /// on `Ready` (which carries both session_guid and the play:server vm_id —
    /// no separate VM-polling needed), or `Err` on `Error` (master fires this
    /// when `SessionExited` arrives before Ready, e.g. Studio crashed during
    /// launch).
    pub async fn start_multiplayer_test(
        &self,
        opts: StartMultiplayerTestOpts,
    ) -> Result<MultiplayerTestServer> {
        let mut stream = self.transport.master()
            .launch_multiplayer_test_server(proto::LaunchMultiplayerTestServerRequest {
                backend: self.id.clone(),
                place_file: opts.place_file,
                place_id: opts.place_id,
                fflags: opts.fflags,
                profile: opts.profile,
                run_id: opts.run_id,
                no_hud: opts.no_hud,
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("launch_multiplayer_test_server failed: {e}"))?;

        while let Ok(Some(view)) = stream.message().await {
            let event = view.to_owned_message();
            match event.event {
                Some(proto::launch_multiplayer_test_server_event::Event::Ready(ready)) => {
                    let session_guid = ready.session_guid;
                    let vm_id = ready.vm_id;
                    // Master only fires Ready after stamping the VM with this
                    // session_guid in its snapshot, so a single get_state is
                    // sufficient — no polling needed.
                    let state = self.transport.master()
                        .get_state(proto::GetStateRequest::default())
                        .await
                        .map_err(|e| anyhow!("get_state after Ready failed: {e}"))?
                        .into_owned();
                    let snap = state.vms.into_iter()
                        .find(|v| v.vm_id == vm_id)
                        .ok_or_else(|| anyhow!("Ready fired for vm_id {vm_id} but VM is no longer in state"))?;
                    let server_vm = Vm::from_snapshot(snap, self.transport.clone());
                    return Ok(MultiplayerTestServer {
                        inner: server_vm,
                        transport: self.transport.clone(),
                        session_backend_id: self.id.clone(),
                        session_guid,
                    });
                }
                Some(proto::launch_multiplayer_test_server_event::Event::Error(err)) => {
                    bail!("multiplayer-test server launch failed: {}", err.message);
                }
                _ => {} // Launching — keep waiting
            }
        }
        bail!("launch_multiplayer_test_server stream ended without Ready or Error event")
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
                    // AND its session_guid matches this Studio instance.
                    let edit = studio.wait_for_vm(
                        |v| v.mode == "edit" && v.dom == "edit"
                            && v.session_guid.as_deref() == Some(&session_guid),
                        VM_WAIT_TIMEOUT_MS,
                    ).await?;
                    studio.edit_vm = Some(edit);
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

#[derive(Default, Clone)]
pub struct StartMultiplayerTestOpts {
    pub place_file: Option<String>,
    pub place_id: Option<u64>,
    pub fflags: Vec<String>,
    pub profile: bool,
    pub run_id: Option<String>,
    pub no_hud: bool,
}

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

    /// Poll master state until a connected VM matching `pred` appears.
    /// Scope as needed via predicate (e.g. `v.session_guid == Some(self.session_guid.clone())`).
    pub async fn wait_for_vm<F>(&self, pred: F, timeout_ms: u64) -> Result<Vm>
    where
        F: Fn(&Vm) -> bool,
    {
        wait_for_vm_on(&self.transport, pred, timeout_ms).await
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

        let vm_mode = mode.to_string();
        let session = self.session_guid.clone();
        let vm_mode_for_server = vm_mode.clone();
        let session_for_server = session.clone();
        self.server_vm = Some(self.wait_for_vm(
            move |v| v.mode == vm_mode_for_server && v.dom == "server"
                && v.session_guid.as_deref() == Some(&session_for_server),
            VM_WAIT_TIMEOUT_MS,
        ).await?);

        if mode == "test" || mode == "play" {
            let vm_mode_for_client = vm_mode.clone();
            let session_for_client = session.clone();
            self.client_vm = Some(self.wait_for_vm(
                move |v| v.mode == vm_mode_for_client && v.dom == "client"
                    && v.session_guid.as_deref() == Some(&session_for_client),
                VM_WAIT_TIMEOUT_MS,
            ).await?);
        } else {
            self.client_vm = None;
        }
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
        let state = self.transport.master()
            .get_state(proto::GetStateRequest::default())
            .await
            .map_err(|e| anyhow!("get_state failed: {e}"))?
            .into_owned();
        Ok(state.vms.into_iter()
            .filter(|v| v.backend_id.as_deref() == Some(&self.backend_id)
                && v.session_guid.as_deref() == Some(&self.session_guid))
            .map(|s| Vm::from_snapshot(s, self.transport.clone()))
            .collect())
    }

}

// ---------------------------------------------------------------------------
// MultiplayerTestServer — Vm-with-extras: same data plane as any Vm
// (run_code, vm_id, etc. via Deref), plus session-lifecycle methods.
// ---------------------------------------------------------------------------

pub struct MultiplayerTestServer {
    inner: Vm,
    transport: Arc<Transport>,
    session_backend_id: String,
    session_guid: String,
}

impl std::ops::Deref for MultiplayerTestServer {
    type Target = Vm;
    fn deref(&self) -> &Vm { &self.inner }
}

impl MultiplayerTestServer {
    /// Master-minted session GUID identifying the MP server process.
    /// Stable for the process's lifetime even if the Vm reconnects.
    pub fn session_guid(&self) -> &str { &self.session_guid }

    pub async fn connect_client(&self) -> Result<MultiplayerTestClient> {
        // Snapshot existing play-client VM IDs so we know which new VM is ours.
        let state = self.transport.master()
            .get_state(proto::GetStateRequest::default())
            .await
            .map_err(|e| anyhow!("get_state failed: {e}"))?
            .into_owned();
        let backend_id = self.session_backend_id.clone();
        let session_guid = self.session_guid.clone();
        let pre_existing: std::collections::HashSet<String> = state.vms.iter()
            .filter(|v| v.backend_id.as_deref() == Some(&backend_id)
                && v.session_guid.as_deref() == Some(&session_guid)
                && v.mode.as_deref() == Some("play")
                && v.dom.as_deref() == Some("client"))
            .map(|v| v.vm_id.clone())
            .collect();

        let resp = self.transport.master()
            .connect_multiplayer_test_client(proto::ConnectMultiplayerTestClientRequest { session_guid: self.session_guid.clone(), ..Default::default() })
            .await
            .map_err(|e| anyhow!("connect_client failed: {e}"))?
            .into_owned();

        // Poll until a new play:client VM appears.
        let deadline = Instant::now() + Duration::from_millis(VM_WAIT_TIMEOUT_MS);
        let client_vm = loop {
            let snap = self.transport.master()
                .get_state(proto::GetStateRequest::default())
                .await
                .map_err(|e| anyhow!("get_state failed: {e}"))?
                .into_owned();
            let found = snap.vms.into_iter().find(|v|
                v.connected
                && v.mode.as_deref() == Some("play")
                && v.dom.as_deref() == Some("client")
                && !pre_existing.contains(&v.vm_id)
            );
            if let Some(v) = found {
                break Vm::from_snapshot(v, self.transport.clone());
            }
            if Instant::now() >= deadline {
                bail!("timed out waiting for new play:client VM to register");
            }
            tokio::time::sleep(Duration::from_millis(VM_POLL_INTERVAL_MS)).await;
        };

        Ok(MultiplayerTestClient {
            inner: client_vm,
            transport: self.transport.clone(),
            server_session_guid: self.session_guid.clone(),
            client_id: resp.client_id,
        })
    }

    pub async fn close(&self) -> Result<()> {
        self.transport.master()
            .close_multiplayer_test_server(proto::CloseMultiplayerTestServerRequest { session_guid: self.session_guid.clone(), ..Default::default() })
            .await
            .map_err(|e| anyhow!("close_multiplayer_test_server failed: {e}"))?;
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// MultiplayerTestClient — same shape as MultiplayerTestServer: Vm + extras.
// ---------------------------------------------------------------------------

pub struct MultiplayerTestClient {
    inner: Vm,
    transport: Arc<Transport>,
    server_session_guid: String,
    client_id: String,
}

impl std::ops::Deref for MultiplayerTestClient {
    type Target = Vm;
    fn deref(&self) -> &Vm { &self.inner }
}

impl MultiplayerTestClient {
    /// Per-session client index assigned by master at connect time.
    pub fn client_id(&self) -> &str { &self.client_id }

    pub async fn disconnect(&self) -> Result<()> {
        self.transport.master()
            .disconnect_multiplayer_test_client(proto::DisconnectMultiplayerTestClientRequest {
                client_id: self.client_id.clone(),
                session_guid: self.server_session_guid.clone(),
                ..Default::default()
            })
            .await
            .map_err(|e| anyhow!("disconnect_multiplayer_test_client failed: {e}"))?;
        Ok(())
    }
}

