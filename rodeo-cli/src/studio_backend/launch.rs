//! Rodeo-specific Studio / multiplayer-test launch wrappers.
//!
//! Composes [`rbx_control::studio::launch::Studio`] and
//! [`rbx_control::studio::multiplayer_test::{MultiplayerTestServer, MultiplayerTestClient}`]
//! with rodeo orchestration: launch-slot daemon gating, rodeo plugin install,
//! `__RODEO_SESSION_GUID__` attribute stamping onto place files, and log-scanner
//! binding. Type names here match the rbx-control side verbatim — rodeo's
//! wrapper `MultiplayerTestServer` owns an `inner:
//! rbx_control::studio::multiplayer_test::MultiplayerTestServer` and adds
//! rodeo-only state (plugin_path, session_guid, client registry).

use anyhow::{bail, Context, Result};
use rbx_dom_weak::{InstanceBuilder, WeakDom};
use std::path::{Path, PathBuf};

use crate::studio_backend::plugin_embed;

// Re-exports so call sites that reach `crate::studio_backend::{SaveMode, PlaceTarget, FflagConfig}`
// (via `pub use launch::*;` in mod.rs) keep working unchanged.
pub use rbx_control::fflags::FflagConfig;
pub use rbx_control::studio::launch::{PlaceTarget, SaveMode};

/// Parse a rodeo CLI `--save` argument into a `SaveMode`.
/// - `None` → `NoSave`
/// - `Some("")` (bare `--save` flag) → `SaveInPlace`
/// - `Some(path)` → `SaveToPath(path)`
///
/// The empty-string-means-SaveInPlace convention is rodeo's CLI shape, not
/// general Studio automation semantics, so it lives here rather than in
/// rbx-control.
pub fn parse_save_mode(save: Option<String>) -> SaveMode {
    match save {
        None => SaveMode::NoSave,
        Some(s) if s.is_empty() => SaveMode::SaveInPlace,
        Some(path) => SaveMode::SaveToPath(path),
    }
}

/// Append microprofiler auto-capture fflags to an existing `FflagConfig`
/// when the launch request asks for profiling. Centralized here so every
/// launch path (Studio, MP-test) and every client (CLI, rodeo-client,
/// rodeo-client-ts, rodeo-client-lune) gets identical fflag injection without
/// each having to know the magic FFlag names. Skips any fflag the caller
/// already set so explicit user overrides win.
///
/// Reads `RODEO_PROFILE_FRAME_INTERVAL` and `RODEO_PROFILE_NUM_FRAMES` from
/// the backend host's environment for tuning; both default to 60.
pub fn inject_profile_fflags(fflags: FflagConfig) -> FflagConfig {
    let interval = std::env::var("RODEO_PROFILE_FRAME_INTERVAL")
        .unwrap_or_else(|_| "60".to_string());
    let num_frames = std::env::var("RODEO_PROFILE_NUM_FRAMES")
        .unwrap_or_else(|_| "60".to_string());

    let injected = [
        "FFlagDebugMicroProfilerAutoCaptureRawEnabled=true".to_string(),
        format!("FIntDebugMicroProfilerAutoCaptureRawInterval={interval}"),
        format!("FIntDebugMicroProfilerAutoCaptureRawNumFrames={num_frames}"),
    ];

    let mut out = fflags;
    for flag in &injected {
        let key = flag.split('=').next().unwrap();
        if !out.overrides.iter().any(|f| f.starts_with(key)) {
            out.overrides.push(flag.clone());
        }
    }
    out
}

// ---------------------------------------------------------------------------
// Rodeo StudioOptions — adds session_guid + plugin port on top of generic opts.
// ---------------------------------------------------------------------------

#[derive(Clone, Debug)]
pub struct StudioOptions {
    /// Port the rodeo plugin connects to (baked into the plugin's `flags` module).
    pub port: u16,
    pub background: bool,
    pub save: SaveMode,
    pub fflags: FflagConfig,
    pub detached: bool,
    /// Strip Studio dock UI panels for a minimal launch (restored on cleanup).
    pub no_hud: bool,
    /// Master-minted session identity. Stamped into the plugin's
    /// `flags.SESSION_GUID` and (for local-file launches) into the place file's
    /// `__RODEO_SESSION_GUID__` attribute, so the plugin's activation gate
    /// matches this launch.
    pub session_guid: String,
}

// ---------------------------------------------------------------------------
// Studio — wraps rbx_control::studio::launch::Studio with rodeo state.
// ---------------------------------------------------------------------------

/// Handle to a rodeo-managed Studio instance. Composes:
/// - `inner`: generic process + fflag + save-on-exit mechanics
/// - `daemon_slot`: launch-slot gate (released on drop)
/// - `plugin_path`: rodeo plugin file to delete on cleanup
/// - `log_path`: paired by the log scanner shortly after launch
///
/// Field declaration order matters for Drop: `daemon_slot` drops first
/// (issues `ReleaseSlot`), `inner` drops last (save + kill + fflag restore).
pub struct Studio {
    /// Daemon slot handle — released on drop, letting the next queued launch
    /// through. Declared first so field-drop-order releases before inner's
    /// save+kill sequence.
    daemon_slot: std::sync::Mutex<Option<crate::studio_backend::daemon::SlotHandle>>,
    /// Master-minted session identity.
    session_guid: String,
    /// Log file path, resolved asynchronously by the log scanner after launch.
    process_log: rbx_control::studio::log_scanner::ProcessLog,
    /// Rodeo plugin file written by `install_launch_plugin` — deleted on cleanup
    /// so a subsequent launch doesn't pick up this launch's plugin.
    plugin_path: Option<PathBuf>,
    /// Inner generic Studio. Declared last so it drops last (runs save + kill
    /// + fflag restore after daemon slot has been released).
    inner: rbx_control::studio::launch::Studio,
}

impl Studio {
    /// Spawn a new Studio instance. Acquires daemon slot, installs rodeo plugin,
    /// prepares the place file (stamping session_guid), and launches Studio.
    /// Call [`Self::wait_for_ready`] after storing the handle to block on login.
    pub fn spawn(target: PlaceTarget, opts: StudioOptions) -> Result<Self> {
        let session_guid = opts.session_guid.clone();
        let sg_short = &session_guid[..8.min(session_guid.len())];
        tracing::info!(session_guid = sg_short, "spawn: acquiring daemon slot");

        let daemon_slot = match crate::studio_backend::daemon::acquire_slot(
            &crate::studio_backend::daemon_paths(),
            crate::studio_backend::DAEMON_SUBCOMMAND,
        ) {
            Ok(slot) => {
                tracing::info!(session_guid = sg_short, "spawn: acquired daemon slot");
                Some(slot)
            }
            Err(e) => {
                tracing::warn!(session_guid = sg_short, "studio daemon unavailable, launching without gate: {e}");
                None
            }
        };

        tracing::info!(session_guid = sg_short, "spawn: installing launch plugin");
        let plugin_path = install_launch_plugin(&target, opts.port, &session_guid)?;

        // Prepare the place file (stamp __RODEO_SESSION_GUID__, handle temp
        // files for NoSave mode). For PlaceId targets, skip prep — Studio
        // downloads the file from Roblox.
        let prepared_target = match &target {
            PlaceTarget::PlaceId { .. } => target.clone(),
            PlaceTarget::Content(_) => {
                bail!("Content variant is for the multiplayer-test flow; edit-mode launch should receive File or PlaceId");
            }
            PlaceTarget::File(_) | PlaceTarget::Empty => {
                let place_str = match &target {
                    PlaceTarget::File(p) => Some(p.as_str()),
                    _ => None,
                };
                tracing::info!(session_guid = sg_short, "spawn: preparing place file");
                let place_path = prepare_place(place_str, &opts.save, &session_guid)?;
                PlaceTarget::File(place_path.to_string_lossy().to_string())
            }
        };

        tracing::info!(session_guid = sg_short, "spawn: calling rbx_control Studio::spawn");
        let inner = rbx_control::studio::launch::Studio::spawn(
            prepared_target,
            rbx_control::studio::launch::StudioOptions {
                background: opts.background,
                save: opts.save,
                fflags: opts.fflags,
                detached: opts.detached,
                no_hud: opts.no_hud,
            },
        )?;
        tracing::info!(session_guid = sg_short, pid = inner.pid(), "spawn: Studio process spawned");

        Ok(Studio {
            daemon_slot: std::sync::Mutex::new(daemon_slot),
            session_guid,
            process_log: rbx_control::studio::log_scanner::ProcessLog::new(),
            plugin_path: Some(plugin_path),
            inner,
        })
    }

    /// Wait for Studio login gate, then notify the daemon that the login slot
    /// can be released to the next queued launch.
    pub fn wait_for_ready(&self) {
        let pid = self.inner.pid();
        let sg_short = &self.session_guid[..8.min(self.session_guid.len())];
        tracing::info!(session_guid = sg_short, pid, "wait_for_ready: waiting on login gate stdout");
        self.inner.wait_for_ready();
        tracing::info!(session_guid = sg_short, pid, "wait_for_ready: login gate passed, notifying daemon");
        if let Some(ref mut slot) = *self.daemon_slot.lock().unwrap() {
            let _ = slot.launch_complete(pid, self.inner.detached());
        }
        tracing::info!(session_guid = sg_short, pid, "wait_for_ready: complete");
    }

    // -- Delegates to inner --

    pub fn is_running(&self) -> bool { self.inner.is_running() }
    pub fn detached(&self) -> bool { self.inner.detached() }
    /// Event-driven exit notification. See `launch_control::Child::on_exit`.
    pub fn on_exit(&self, callback: impl FnOnce(std::process::ExitStatus) + Send + 'static) {
        self.inner.on_exit(callback);
    }
    pub fn place_path(&self) -> Option<&Path> { self.inner.place_path() }
    pub fn launched_at(&self) -> std::time::SystemTime { self.inner.launched_at() }
    pub fn save(&self) -> Result<()> { self.inner.save() }
    pub fn kill(&self) { self.inner.kill() }

    // -- Rodeo-only --

    pub fn process_log(&self) -> &rbx_control::studio::log_scanner::ProcessLog { &self.process_log }
    pub fn log_path(&self) -> Option<PathBuf> { self.process_log.get() }

    /// Full cleanup — delegates to inner (save + kill + fflag restore) and
    /// removes the rodeo plugin file.
    pub fn cleanup(&self) {
        self.inner.cleanup();
        if let Some(ref path) = self.plugin_path {
            let _ = std::fs::remove_file(path);
        }
    }
}

impl Drop for Studio {
    fn drop(&mut self) {
        let sg_short = &self.session_guid[..8.min(self.session_guid.len())];
        let detached = self.inner.detached();
        tracing::info!(
            session_guid = sg_short,
            pid = self.inner.pid(),
            detached,
            "Studio::Drop fired (will release daemon slot)"
        );
        if detached {
            // Caller asked Studio to survive parent exit. Skip cleanup —
            // inner Drop handles fflag/layout restore and leaves the Studio
            // process alone. Plugin file stays installed so the running
            // Studio keeps it loaded; explicit `cleanup()` removes it.
            // daemon_slot still drops via field-drop-order.
            return;
        }
        self.cleanup();
        // daemon_slot drops automatically on return (field-drop-order),
        // issuing ReleaseSlot via its own Drop impl.
    }
}

// ---------------------------------------------------------------------------
// MultiplayerTestServer — wraps rbx_control::studio::multiplayer_test::MultiplayerTestServer
// ---------------------------------------------------------------------------

// Client type + options come straight from the generic side — rodeo adds
// nothing to the client lifecycle.
pub use rbx_control::studio::multiplayer_test::{MultiplayerTestClient, MultiplayerTestClientOptions};

/// Options for launching a rodeo play-mode server.
pub struct MultiplayerTestServerOptions {
    pub place: PlaceTarget,
    /// Port for the rodeo plugin WebSocket (not RakNet).
    pub rodeo_port: u16,
    /// RakNet port for game networking (0 = auto-assign).
    pub raknet_port: u16,
    pub background: bool,
    pub fflags: FflagConfig,
    pub user_id: u64,
    /// Master-minted session identity for the whole play session.
    /// MultiplayerTestServer + its MultiplayerTestClients share this one guid.
    pub session_guid: String,
    pub no_hud: bool,
    /// Real `placeId` to seed Studio's `-placeId` flag. 0 = anonymous.
    pub place_id: u64,
    /// Real `universeId` to seed Studio's `-universeId` flag. 0 = unset.
    pub universe_id: u64,
    /// Real `placeVersion` to seed Studio's `-placeVersion` flag. 0 = unset.
    pub place_version: u32,
}

/// Rodeo's play-mode server handle — delegates process + client-container
/// semantics to the inner generic handle, layers rodeo plugin install on top.
pub struct MultiplayerTestServer {
    inner: rbx_control::studio::multiplayer_test::MultiplayerTestServer,
    plugin_path: Option<PathBuf>,
    /// StartServer's `*_Studio_*_last.log` path slot, populated asynchronously
    /// by the log scanner. Per-execution `--logs` capture reads it.
    process_log: rbx_control::studio::log_scanner::ProcessLog,
}

impl MultiplayerTestServer {
    /// Launch a StartServer process. Stages the place file at
    /// `~/Documents/Roblox/server.rbxl` with `__RODEO_SESSION_GUID__` stamped,
    /// installs the rodeo plugin, then calls the generic launcher.
    pub fn launch(opts: MultiplayerTestServerOptions) -> Result<Self> {
        let session_guid = opts.session_guid.clone();

        // Stage the place at ~/Documents/Roblox/server.rbxl in one place; each
        // variant only needs to produce the bytes/copy. The session_guid attr
        // patch is a single tail call so the plugin's activation gate matches.
        let staged_path = match &opts.place {
            PlaceTarget::File(path) => {
                rbx_control::place::stage_local_place(Path::new(path))?
            }
            PlaceTarget::Content(bytes) => {
                rbx_control::place::stage_server_place(bytes)?
            }
            PlaceTarget::Empty => {
                let place = create_minimal_place_with_session_guid(&session_guid);
                let bytes = rbx_control::studio::launch::serialize_place(&place)?;
                rbx_control::place::stage_server_place(&bytes)?
            }
            PlaceTarget::PlaceId { .. } => {
                bail!("published place must be downloaded by the backend before launching MultiplayerTestServer; pass Content instead")
            }
        };
        patch_place_session_guid(&staged_path, &session_guid)?;

        // Install rodeo plugin. Match config has to agree with what Studio will
        // actually see: if we passed real placeId/universeId on the CLI, the
        // plugin's MATCH check must use those real values (not 0/0), or its
        // gate fails before the session_guid attr is even checked.
        let plugin_target = if opts.place_id > 0 {
            PlaceTarget::PlaceId { place_id: opts.place_id, universe_id: Some(opts.universe_id) }
        } else {
            PlaceTarget::Empty
        };
        let plugin_path =
            install_launch_plugin(&plugin_target, opts.rodeo_port, &session_guid)?;

        let inner = rbx_control::studio::multiplayer_test::MultiplayerTestServer::launch(
            rbx_control::studio::multiplayer_test::MultiplayerTestServerOptions {
                raknet_port: opts.raknet_port,
                background: opts.background,
                fflags: opts.fflags,
                user_id: opts.user_id,
                no_hud: opts.no_hud,
                place_id: opts.place_id,
                universe_id: opts.universe_id,
                place_version: opts.place_version,
            },
        )?;

        Ok(MultiplayerTestServer {
            inner,
            plugin_path: Some(plugin_path),
            process_log: rbx_control::studio::log_scanner::ProcessLog::new(),
        })
    }

    // -- Delegates --

    pub fn pid(&self) -> u32 { self.inner.pid() }
    pub fn launched_at(&self) -> std::time::SystemTime { self.inner.launched_at() }
    pub fn process_log(&self) -> &rbx_control::studio::log_scanner::ProcessLog { &self.process_log }
    pub fn log_path(&self) -> Option<PathBuf> { self.process_log.get() }
    pub fn raknet_port(&self) -> u16 { self.inner.raknet_port() }
    pub fn raknet_session_guid(&self) -> &str { self.inner.raknet_session_guid() }
    pub fn play_test_guid(&self) -> &str { self.inner.play_test_guid() }

    /// Register a callback invoked when the server process exits.
    pub fn on_exit(&self, callback: impl FnOnce(std::process::ExitStatus) + Send + 'static) {
        self.inner.on_exit(callback);
    }

    pub fn add_client(&mut self, index: u32, client: MultiplayerTestClient) {
        self.inner.add_client(index, client);
    }
    pub fn remove_client(&mut self, index: u32) -> Option<MultiplayerTestClient> {
        self.inner.remove_client(index)
    }
    pub fn client_by_pid(&self, pid: u32) -> Option<u32> {
        self.inner.client_by_pid(pid)
    }
    pub fn clients(&self) -> &std::collections::HashMap<u32, MultiplayerTestClient> {
        self.inner.clients()
    }

    pub fn cleanup(&mut self) {
        self.inner.cleanup();
        if let Some(ref path) = self.plugin_path {
            let _ = std::fs::remove_file(path);
        }
        // Clean up staged server.rbxl
        if let Some(dir) = dirs::document_dir() {
            let _ = std::fs::remove_file(dir.join("Roblox/server.rbxl"));
        }
    }
}

impl Drop for MultiplayerTestServer {
    fn drop(&mut self) {
        self.cleanup();
    }
}

// ---------------------------------------------------------------------------
// Rodeo-specific helpers: plugin install, place prep, session_guid stamping
// ---------------------------------------------------------------------------

/// Install a patched rodeo plugin for this launch into the Studio plugins
/// directory. Returns the path the plugin was written to (for cleanup).
///
/// For local-file launches we stamped `__RODEO_SESSION_GUID__` onto the staged
/// place's Workspace, so the plugin's activation gate checks the attribute
/// matches `flags.SESSION_GUID`. For published-place launches the place is
/// downloaded by Studio and we can't stamp it — the plugin relies on MATCH
/// (placeId/universeId) for isolation and skips the attribute gate.
fn install_launch_plugin(target: &PlaceTarget, port: u16, session_guid: &str) -> Result<PathBuf> {
    let studio = roblox_install::RobloxStudio::locate()
        .context("failed to locate Roblox Studio install")?;
    let plugins_dir = studio.plugins_path();
    std::fs::create_dir_all(plugins_dir).context("failed to create plugins directory")?;

    let (match_place_id, match_universe_id, check_workspace_session_guid_attr_matches) = match target {
        PlaceTarget::PlaceId { place_id, universe_id } => {
            // Published place — can't stamp attribute on a downloaded place,
            // so skip the attribute gate. MATCH (placeId + universeId) gates.
            (Some(*place_id), *universe_id, false)
        }
        PlaceTarget::File(_) | PlaceTarget::Empty | PlaceTarget::Content(_) => {
            // Local file / empty place / downloaded bytes — we stamped
            // __RODEO_SESSION_GUID__ when preparing the place, so the plugin
            // enforces the match.
            (Some(0), Some(0), true)
        }
    };

    let config = plugin_embed::PluginConfig {
        port,
        host: "localhost".to_string(),
        auto_connect: true,
        settings_panel_enabled: false,
        match_place_id,
        match_universe_id,
        session_guid: Some(session_guid.to_string()),
        check_workspace_session_guid_attr_matches,
    };

    // Filename is unique per launch so concurrent launches on the same port
    // don't race on a shared file (and one launch's Drop cleanup can't delete
    // another launch's plugin mid-boot).
    let plugin_path = plugins_dir.join(format!("rodeo-{port}-{session_guid}.rbxm"));
    plugin_embed::write_patched_plugin(&plugin_path.to_string_lossy(), &config)?;

    Ok(plugin_path)
}

/// Prepare a place file for Studio based on SaveMode. Stamps
/// `__RODEO_SESSION_GUID__` onto the Workspace so the plugin's activation
/// gate matches this launch's plugin.
fn prepare_place(place: Option<&str>, save: &SaveMode, session_guid: &str) -> Result<PathBuf> {
    let temp_dir = Path::new(".rodeo/.temp");
    std::fs::create_dir_all(temp_dir).context("failed to create temp dir")?;

    let has_place = place.is_some_and(|p| !p.is_empty() && Path::new(p).is_file());

    match save {
        SaveMode::NoSave => {
            let ext = if has_place {
                Path::new(place.unwrap())
                    .extension()
                    .and_then(|e| e.to_str())
                    .unwrap_or("rbxl")
            } else {
                "rbxl"
            };
            let temp_path = temp_dir.join(format!("rodeo-{}.{}", uuid::Uuid::new_v4(), ext));
            if has_place {
                std::fs::copy(place.unwrap(), &temp_path)
                    .context("failed to copy place file")?;
                patch_place_session_guid(&temp_path, session_guid)?;
            } else {
                let dom = create_minimal_place_with_session_guid(session_guid);
                rbx_control::studio::launch::write_place(&dom, &temp_path)?;
            }
            Ok(temp_path)
        }
        SaveMode::SaveInPlace => {
            if has_place {
                let path = PathBuf::from(place.unwrap());
                patch_place_session_guid(&path, session_guid)?;
                Ok(path)
            } else {
                let temp_path = temp_dir.join(format!("rodeo-{}.rbxl", uuid::Uuid::new_v4()));
                let dom = create_minimal_place_with_session_guid(session_guid);
                rbx_control::studio::launch::write_place(&dom, &temp_path)?;
                Ok(temp_path)
            }
        }
        SaveMode::SaveToPath(out) => {
            let out_path = PathBuf::from(out);
            if let Some(parent) = out_path.parent() {
                if !parent.as_os_str().is_empty() {
                    std::fs::create_dir_all(parent)
                        .context("failed to create output directory")?;
                }
            }
            if has_place {
                std::fs::copy(place.unwrap(), &out_path)
                    .context("failed to copy place file")?;
                patch_place_session_guid(&out_path, session_guid)?;
            } else {
                let dom = create_minimal_place_with_session_guid(session_guid);
                rbx_control::studio::launch::write_place(&dom, &out_path)?;
            }
            Ok(out_path)
        }
    }
}

/// Create a minimal DataModel with a Workspace stamped with `__RODEO_SESSION_GUID__`.
fn create_minimal_place_with_session_guid(session_guid: &str) -> WeakDom {
    let mut attrs = rbx_dom_weak::types::Attributes::new();
    attrs.insert(
        "__RODEO_SESSION_GUID__".into(),
        rbx_dom_weak::types::Variant::String(session_guid.into()),
    );

    let workspace = InstanceBuilder::new("Workspace")
        .with_property("Attributes", rbx_dom_weak::types::Variant::Attributes(attrs));

    WeakDom::new(InstanceBuilder::new("DataModel").with_child(workspace))
}

/// Patch an existing place file with a `__RODEO_SESSION_GUID__` attribute on Workspace.
fn patch_place_session_guid(path: &Path, session_guid: &str) -> Result<()> {
    let data = std::fs::read(path).context("failed to read place file")?;
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    let mut dom = if ext == "rbxlx" {
        rbx_xml::from_reader(std::io::Cursor::new(data), rbx_xml::DecodeOptions::default())
            .context("failed to parse XML place")?
    } else {
        rbx_binary::from_reader(std::io::Cursor::new(data))
            .context("failed to parse binary place")?
    };

    // Find or create Workspace in the DataModel's children
    let ws_ref = {
        let root = dom.root();
        let mut found = None;
        for &child_ref in root.children() {
            if let Some(child) = dom.get_by_ref(child_ref) {
                if child.class == "Workspace" {
                    found = Some(child_ref);
                    break;
                }
            }
            // Workspace may be nested inside DataModel
            if let Some(child) = dom.get_by_ref(child_ref) {
                for &grandchild_ref in child.children() {
                    if let Some(gc) = dom.get_by_ref(grandchild_ref) {
                        if gc.class == "Workspace" {
                            found = Some(grandchild_ref);
                            break;
                        }
                    }
                }
            }
            if found.is_some() {
                break;
            }
        }
        match found {
            Some(r) => r,
            None => {
                // Rojo-built files may not include Workspace — create it
                let root_ref = dom.root_ref();
                dom.insert(root_ref, InstanceBuilder::new("Workspace"))
            }
        }
    };

    // Build attributes — preserve existing attributes if any
    let ws = dom.get_by_ref_mut(ws_ref).context("invalid Workspace ref")?;
    let attr_key: rbx_dom_weak::Ustr = "Attributes".into();
    let mut attrs = match ws.properties.get(&attr_key) {
        Some(rbx_dom_weak::types::Variant::Attributes(existing)) => existing.clone(),
        _ => rbx_dom_weak::types::Attributes::new(),
    };
    attrs.insert(
        "__RODEO_SESSION_GUID__".into(),
        rbx_dom_weak::types::Variant::String(session_guid.into()),
    );
    ws.properties.insert(
        attr_key,
        rbx_dom_weak::types::Variant::Attributes(attrs),
    );

    rbx_control::studio::launch::write_place(&dom, path)
}
