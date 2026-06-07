//! Generic Studio multiplayer-test launch (`-task StartServer` + `-task StartClient`).
//!
//! Models Studio's multi-process test mode: a server process and one or more
//! client processes cooperating as a playable multi-client session. The server
//! binds a RakNet port and reports a session GUID on stdout; clients join by
//! passing `-parentSessionGuid` + `-port`.
//!
//! **Staging contract**: the caller must stage the place file at
//! `~/Documents/Roblox/server.rbxl` before calling
//! [`MultiplayerTestServer::launch`] — that's where Studio's `StartServer`
//! task reads from. Use [`crate::place::stage_server_place`] or
//! [`crate::place::stage_local_place`] to do the staging.
//!
//! Plugin installation (if any) is also the caller's responsibility — any
//! file dropped into the Studio plugins directory is loaded by all Studio
//! instances, including the processes this module launches.

use anyhow::{Context, Result};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant, SystemTime};

use crate::fflags::{self, FflagConfig, FflagHandle, FflagTarget};
use crate::studio::log_scanner::ProcessLog;

// ---------------------------------------------------------------------------
// Server
// ---------------------------------------------------------------------------

/// Options for launching a multiplayer-test server.
pub struct MultiplayerTestServerOptions {
    /// RakNet port for game networking. 0 = auto-assign (Studio picks).
    pub raknet_port: u16,
    pub background: bool,
    pub fflags: FflagConfig,
    pub user_id: u64,
    pub no_hud: bool,
    /// Real `placeId` to pass on the StartServer command line. 0 = legacy
    /// "anonymous test" mode (in-VM `game.PlaceId` reads as 0).
    pub place_id: u64,
    /// Real `universeId` for `-universeId`. 0 = unset.
    pub universe_id: u64,
    /// Real `placeVersion` for `-placeVersion`. 0 = unset.
    pub place_version: u32,
}

/// Handle to a StartServer process — the host side of a multiplayer test.
///
/// Reads the RakNet session GUID and port from the server's stdout. Those
/// are used by [`MultiplayerTestClient`] to join the session.
///
/// Owns its clients (`clients: HashMap<u32, MultiplayerTestClient>`) so
/// dropping the server cascades to all connected clients via Rust ownership,
/// killing their Studio processes.
pub struct MultiplayerTestServer {
    handle: launch_control::Child,
    raknet_port: u16,
    /// Multiplayer-session GUID parsed from StartServer's stdout. Passed to
    /// clients as `-parentSessionGuid` so they join this session. Distinct
    /// from any consumer-level session identity.
    raknet_session_guid: String,
    /// Shared play-test GUID generated at server launch; clients inherit it.
    play_test_guid: String,
    fflag_handle: Option<FflagHandle>,
    layout_handle: Option<filepatch::Handle>,
    cleaned: AtomicBool,
    /// Wall-clock time the StartServer was spawned. Used by the log scanner to
    /// pair this process with the matching `*_Studio_*_last.log` file.
    launched_at: SystemTime,
    /// Clients that have joined this server, keyed by 1-based index.
    /// Cascades on drop.
    clients: HashMap<u32, MultiplayerTestClient>,
}

impl MultiplayerTestServer {
    /// Launch a StartServer process targeting the place file staged at
    /// `~/Documents/Roblox/server.rbxl`.
    ///
    /// Blocks until the server prints its session GUID and RakNet port to
    /// stdout (30s timeout).
    pub fn launch(opts: MultiplayerTestServerOptions) -> Result<Self> {
        let fflag_handle = if !opts.fflags.overrides.is_empty() || opts.fflags.file.is_some() {
            fflags::apply(
                FflagTarget::Studio,
                &opts.fflags.overrides,
                opts.fflags.file.as_deref(),
            )?
        } else {
            None
        };

        let layout_handle = if opts.no_hud {
            super::layout::apply_no_hud().context("failed to apply --no-hud layout patch")?
        } else {
            None
        };

        let studio_path = super::launch::studio_application_path()?;
        let play_test_guid = uuid::Uuid::new_v4().to_string();
        let parent_guid = uuid::Uuid::new_v4().to_string();
        let launched_at = SystemTime::now();

        let place_id_str = opts.place_id.to_string();
        let universe_id_str = opts.universe_id.to_string();
        let place_version_str = opts.place_version.to_string();

        let mut handle = launch_control::Command::new(&studio_path)
            .args([
                "-task", "StartServer",
                "-placeId", &place_id_str,
                "-universeId", &universe_id_str,
                "-creatorType", "0",
                "-creatorId", "0",
                "-userid", &opts.user_id.to_string(),
                "-parentPid", &std::process::id().to_string(),
                "-parentSessionGuid", &parent_guid,
                "-instanceId", "StudioServer",
                "-playTestSessionGuid", &play_test_guid,
                "-numTestServerPlayersUponStartup", "0",
                "-port", &opts.raknet_port.to_string(),
                "-placeVersion", &place_version_str,
            ])
            .background(opts.background)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()
            .context("failed to launch StartServer")?;

        let stdout = handle
            .stdout
            .take()
            .context("no stdout from StartServer")?;
        let stderr = handle
            .stderr
            .take()
            .context("no stderr from StartServer")?;

        let (raknet_session_guid, raknet_port) =
            read_server_startup(&stdout, &stderr, opts.raknet_port)?;

        Ok(MultiplayerTestServer {
            handle,
            raknet_port,
            raknet_session_guid,
            play_test_guid,
            fflag_handle,
            layout_handle,
            cleaned: AtomicBool::new(false),
            launched_at,
            clients: HashMap::new(),
        })
    }

    pub fn pid(&self) -> u32 {
        self.handle.id()
    }

    /// Wall-clock time the StartServer process was spawned. Used by the log
    /// scanner to claim the StartServer's `*_Studio_*_last.log` file.
    pub fn launched_at(&self) -> SystemTime {
        self.launched_at
    }

    pub fn raknet_port(&self) -> u16 {
        self.raknet_port
    }

    pub fn raknet_session_guid(&self) -> &str {
        &self.raknet_session_guid
    }

    pub fn play_test_guid(&self) -> &str {
        &self.play_test_guid
    }

    pub fn is_running(&mut self) -> bool {
        self.handle.try_wait().ok().map_or(true, |s| s.is_none())
    }

    /// Register a callback invoked when the server process exits.
    /// Event-driven (no polling). See `launch_control::Child::on_exit`.
    pub fn on_exit(&self, callback: impl FnOnce(std::process::ExitStatus) + Send + 'static) {
        self.handle.on_exit(callback);
    }

    pub fn focus(&self) -> Result<()> {
        self.handle.focus().context("failed to focus server")
    }

    pub fn kill(&mut self) {
        let _ = self.handle.kill();
    }

    /// Restore fflags + kill. Idempotent.
    pub fn cleanup(&mut self) {
        if self.cleaned.swap(true, Ordering::Relaxed) {
            return;
        }
        if let Some(ref handle) = self.fflag_handle {
            handle.restore();
        }
        if let Some(ref handle) = self.layout_handle {
            handle.restore();
        }
        self.kill();
    }

    // -- Client container --
    //
    // Dropping the server drops the clients HashMap, which drops each
    // MultiplayerTestClient, each of which kills its Studio process. This
    // gives "drop session → kill all clients" for free via Rust ownership.

    /// Insert a client by index. Replaces any existing client at that index
    /// (dropping it and killing its process).
    pub fn add_client(&mut self, index: u32, client: MultiplayerTestClient) {
        self.clients.insert(index, client);
    }

    /// Remove a client by index, transferring ownership to the caller.
    /// Not calling `.kill()` on the returned client lets you detach it.
    pub fn remove_client(&mut self, index: u32) -> Option<MultiplayerTestClient> {
        self.clients.remove(&index)
    }

    /// Find a client's index by its PID.
    pub fn client_by_pid(&self, pid: u32) -> Option<u32> {
        self.clients
            .iter()
            .find_map(|(i, c)| if c.pid() == pid { Some(*i) } else { None })
    }

    /// Next free client index (1-based). Returns 1 if no clients exist.
    pub fn next_client_index(&self) -> u32 {
        self.clients.keys().max().map(|k| k + 1).unwrap_or(1)
    }

    /// Read-only access to the clients map.
    pub fn clients(&self) -> &HashMap<u32, MultiplayerTestClient> {
        &self.clients
    }
}

impl Drop for MultiplayerTestServer {
    fn drop(&mut self) {
        self.cleanup();
    }
}

// ---------------------------------------------------------------------------
// Client
// ---------------------------------------------------------------------------

/// Options for launching a multiplayer-test client.
pub struct MultiplayerTestClientOptions {
    /// RakNet port of the server (from [`MultiplayerTestServer::raknet_port`]).
    pub raknet_port: u16,
    /// Server's RakNet session GUID (from [`MultiplayerTestServer::raknet_session_guid`]).
    pub raknet_session_guid: String,
    /// Server's PID — passed as `-parentPid` for IPC.
    pub server_pid: u32,
    /// Shared play-test GUID (from [`MultiplayerTestServer::play_test_guid`]).
    pub play_test_guid: String,
    /// Client index (1-based). Used to generate the instanceId and log name.
    pub index: u32,
    pub background: bool,
    pub user_id: u64,
    /// If true, skip killing the client on cleanup.
    pub detached: bool,
    pub no_hud: bool,
    /// Real `placeId` (matches the server's `placeId`). 0 = legacy mode.
    pub place_id: u64,
    /// Real `universeId` (matches the server's `universeId`). 0 = unset.
    pub universe_id: u64,
    /// Real `placeVersion` (matches the server's `placeVersion`). Studio's
    /// `StartClient` may or may not honor `-placeVersion`; we pass it
    /// optimistically and watch the log on first run.
    pub place_version: u32,
}

/// Handle to a StartClient process connected to a running server.
///
/// The client loads whatever plugin the caller installed in the shared Studio
/// plugins directory — no per-client plugin install. The plugin auto-detects
/// its role (server vs client) via RunService.
pub struct MultiplayerTestClient {
    pid: u32,
    index: u32,
    detached: bool,
    layout_handle: Option<filepatch::Handle>,
    cleaned: AtomicBool,
    /// Wall-clock time the StartClient was spawned. Used by the log scanner to
    /// pair this process with the matching `*_Studio_*_last.log` file.
    launched_at: SystemTime,
    /// Per-process log slot populated by `LogScannerHandle::pair`.
    process_log: ProcessLog,
}

impl MultiplayerTestClient {
    /// Launch a StartClient process joining a running server.
    pub fn launch(opts: MultiplayerTestClientOptions) -> Result<Self> {
        let layout_handle = if opts.no_hud {
            super::layout::apply_no_hud().context("failed to apply --no-hud layout patch")?
        } else {
            None
        };

        let studio_path = super::launch::studio_application_path()?;
        let instance_id = format!("StudioPlayer_{}", opts.index - 1);
        let launched_at = SystemTime::now();

        tracing::debug!(
            raknet_port = opts.raknet_port,
            server_pid = opts.server_pid,
            raknet_session_guid = opts.raknet_session_guid.as_str(),
            play_test_guid = opts.play_test_guid.as_str(),
            index = opts.index,
            instance_id = instance_id.as_str(),
            "launching StartClient"
        );

        let place_id_str = opts.place_id.to_string();
        let universe_id_str = opts.universe_id.to_string();
        let place_version_str = opts.place_version.to_string();

        let handle = launch_control::Command::new(&studio_path)
            .args([
                "-task", "StartClient",
                "-placeId", &place_id_str,
                "-universeId", &universe_id_str,
                // Studio's StartClient may reject -placeVersion. If so we'll see
                // it in the Studio log on first run with a real id and can drop
                // these two args. Passing them keeps the client identity in
                // sync with the server when supported.
                "-placeVersion", &place_version_str,
                "-userid", &opts.user_id.to_string(),
                "-parentPid", &opts.server_pid.to_string(),
                "-parentSessionGuid", &opts.raknet_session_guid,
                "-instanceId", &instance_id,
                "-playTestSessionGuid", &opts.play_test_guid,
                "-port", &opts.raknet_port.to_string(),
                "-numTestServerPlayersUponStartup", "1",
                "-rbxTransportToken", "bG9jYWxfdGVzdA==",
                "-playerEmulatorSerializedValues",
                r#"{"EmulatedCountryCode":"","EmulatedGameLocale":"","CustomPoliciesEnabled":false,"TextElongationFactor":0,"PseudolocalizationEnabled":false,"PlayerEmulationEnabled":false}"#,
            ])
            .background(opts.background)
            .spawn()
            .context("failed to launch StartClient")?;

        tracing::debug!(pid = handle.id(), "StartClient spawned");

        Ok(MultiplayerTestClient {
            pid: handle.id(),
            index: opts.index,
            detached: opts.detached,
            layout_handle,
            cleaned: AtomicBool::new(false),
            launched_at,
            process_log: ProcessLog::new(),
        })
    }

    pub fn pid(&self) -> u32 {
        self.pid
    }

    pub fn index(&self) -> u32 {
        self.index
    }

    /// Wall-clock time the StartClient process was spawned. Used by the log
    /// scanner to claim the StartClient's `*_Studio_*_last.log` file.
    pub fn launched_at(&self) -> SystemTime {
        self.launched_at
    }

    pub fn process_log(&self) -> &ProcessLog {
        &self.process_log
    }

    pub fn log_path(&self) -> Option<std::path::PathBuf> {
        self.process_log.get()
    }

    pub fn is_running(&self) -> bool {
        if self.pid == 0 {
            return false;
        }
        #[cfg(unix)]
        unsafe {
            libc::kill(self.pid as i32, 0) == 0
        }
        #[cfg(not(unix))]
        {
            false
        }
    }

    pub fn kill(&self) {
        if self.pid > 0 {
            #[cfg(unix)]
            unsafe {
                libc::kill(self.pid as i32, libc::SIGKILL);
            }
        }
    }

    /// Kill the process unless detached. Idempotent.
    pub fn cleanup(&self) {
        if self.cleaned.swap(true, Ordering::Relaxed) {
            return;
        }
        if let Some(ref handle) = self.layout_handle {
            handle.restore();
        }
        if !self.detached {
            self.kill();
        }
    }
}

impl Drop for MultiplayerTestClient {
    fn drop(&mut self) {
        self.cleanup();
    }
}

// ---------------------------------------------------------------------------
// StartServer stdout parser
// ---------------------------------------------------------------------------

/// Read the server's RakNet session GUID and port from its stdio line channels.
/// Blocks until both are found or 30s timeout.
///
/// These are Roblox FLog lines, which land on stderr (Windows) or stdout
/// (macOS), so both streams are polled.
fn read_server_startup(
    stdout: &launch_control::ChildStdout,
    stderr: &launch_control::ChildStderr,
    specified_port: u16,
) -> Result<(String, u16)> {
    let mut session_guid: Option<String> = None;
    let mut raknet_port: Option<u16> = if specified_port > 0 { Some(specified_port) } else { None };
    let deadline = Instant::now() + Duration::from_secs(30);

    loop {
        if Instant::now() >= deadline {
            break;
        }

        let line = match stdout.try_recv().or_else(|_| stderr.try_recv()) {
            Ok(l) => l,
            Err(_) => {
                std::thread::sleep(Duration::from_millis(20));
                continue;
            }
        };

        // Session GUID: "Session GUID is <uuid>"
        if session_guid.is_none() && line.contains("Session GUID is ") {
            if let Some(guid) = line.split("Session GUID is ").nth(1) {
                let guid = guid.trim();
                if guid.len() >= 36 {
                    session_guid = Some(guid[..36].to_string());
                }
            }
        }

        // RakNet port: "Started Raknet network server 127.0.0.1|<port>"
        if raknet_port.is_none() {
            if let Some(idx) = line.find("Started Raknet network server") {
                if let Some(pipe_idx) = line[idx..].find('|') {
                    let port_str = &line[idx + pipe_idx + 1..];
                    let port_str = port_str.trim();
                    if let Ok(port) = port_str.parse::<u16>() {
                        raknet_port = Some(port);
                    }
                }
            }
        }

        if session_guid.is_some() && raknet_port.is_some() {
            break;
        }
    }

    let session_guid = session_guid.context("timeout waiting for server session GUID")?;
    let raknet_port = raknet_port.context("timeout waiting for server RakNet port")?;

    tracing::info!(guid = &session_guid[..8], port = raknet_port, "play server started");

    Ok((session_guid, raknet_port))
}
