//! Rodeo-specific Studio launch wrappers.
//!
//! Composes [`rbx_control::studio::launch::Studio`] with rodeo orchestration:
//! installs the static rodeo plugin, generates the RunScript bootstrap that
//! stamps `rodeoSession`/`rodeoPort` onto the Workspace at launch (so the
//! plugin routes to this launch), and binds the log scanner. No place-file
//! mutation: the original file opens unchanged.

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
    /// Port the rodeo plugin connects to. Stamped as the `rodeoPort` Workspace
    /// attribute by the RunScript bootstrap so the static plugin connects here.
    pub port: u16,
    pub background: bool,
    pub save: SaveMode,
    pub fflags: FflagConfig,
    pub detached: bool,
    /// Strip Studio dock UI panels for a minimal launch (restored on cleanup).
    pub no_hud: bool,
    /// Master-minted session identity. Stamped as the `rodeoSession` Workspace
    /// attribute by the RunScript bootstrap; the plugin sends it on the WS
    /// handshake so master correlates the connecting DOM to this launch.
    pub session_guid: String,
}

// ---------------------------------------------------------------------------
// Studio — wraps rbx_control::studio::launch::Studio with rodeo state.
// ---------------------------------------------------------------------------

/// Handle to a rodeo-managed Studio instance. Composes:
/// - `inner`: generic process + fflag + save-on-exit mechanics
/// - `log_path`: paired by the log scanner shortly after launch
///
/// The rodeo plugin is a permanent static install (shared with manual use), so
/// there's no per-launch plugin file to track or delete.
pub struct Studio {
    /// Master-minted session identity.
    session_guid: String,
    /// Inner generic Studio. Drop runs save + kill + fflag restore.
    inner: rbx_control::studio::launch::Studio,
}

impl Studio {
    /// Spawn a new Studio instance. Installs the rodeo plugin, prepares the
    /// place file (stamping session_guid), and launches Studio. Readiness is
    /// signaled by the plugin's WebSocket connection, not by this handle.
    pub fn spawn(target: PlaceTarget, opts: StudioOptions) -> Result<Self> {
        let session_guid = opts.session_guid.clone();
        let sg_short = &session_guid[..8.min(session_guid.len())];

        tracing::info!(session_guid = sg_short, "spawn: ensuring static plugin installed");
        install_static_plugin()?;

        // Generate the RunScript bootstrap. It stamps `rodeoSession`/`rodeoPort`
        // onto the Workspace once Studio is up, so the static plugin routes to
        // this launch's serve port and master can correlate the DOM. No place
        // mutation needed.
        tracing::info!(session_guid = sg_short, "spawn: writing RunScript bootstrap");
        let bootstrap = write_bootstrap_script(&session_guid, opts.port)?;

        // Prepare the place file (temp copy for NoSave, original for SaveInPlace,
        // output copy for SaveToPath; synthesize a minimal place for Empty so
        // RunScript has a file to open). For PlaceId targets, skip prep — Studio
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
                let place_path = prepare_place(place_str, &opts.save)?;
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
                run_script_file: Some(bootstrap),
            },
        )?;
        tracing::info!(session_guid = sg_short, pid = inner.pid(), "spawn: Studio process spawned");

        Ok(Studio {
            session_guid,
            inner,
        })
    }

    // -- Delegates to inner --

    pub fn detached(&self) -> bool { self.inner.detached() }
    /// Event-driven exit notification. See `launch_control::Child::on_exit`.
    pub fn on_exit(&self, callback: impl FnOnce(std::process::ExitStatus) + Send + 'static) {
        self.inner.on_exit(callback);
    }
    pub fn place_path(&self) -> Option<&Path> { self.inner.place_path() }
    pub fn save(&self) -> Result<()> { self.inner.save() }
    pub fn warm_save_menu_once(&self) -> bool { self.inner.warm_save_menu_once() }
    pub fn kill(&self) { self.inner.kill() }

    /// Full cleanup — delegates to inner (save + kill + fflag restore). The
    /// static plugin is a permanent install and is intentionally left in place.
    pub fn cleanup(&self) {
        self.inner.cleanup();
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
            "Studio::Drop fired"
        );
        if detached {
            // Caller asked Studio to survive parent exit. Skip cleanup —
            // inner Drop handles fflag/layout restore and leaves the Studio
            // process alone. The static plugin is a permanent install, so
            // there's nothing launch-specific to remove either way.
            return;
        }
        self.cleanup();
    }
}

// ---------------------------------------------------------------------------
// Rodeo-specific helpers: static plugin install, RunScript bootstrap, place prep
// ---------------------------------------------------------------------------

/// Ensure the static rodeo plugin is installed in the Studio plugins directory.
///
/// The plugin carries no launch-specific config — config arrives at runtime via
/// the `rodeoPort`/`rodeoSession` Workspace attributes the RunScript bootstrap
/// sets — so this writes the same `rodeo.rbxm` the manual `rodeo plugin` command
/// does. One shared static plugin per machine: never deleted on cleanup, and
/// overwriting keeps the installed plugin in lockstep with the running CLI.
fn install_static_plugin() -> Result<()> {
    let studio = roblox_install::RobloxStudio::locate()
        .context("failed to locate Roblox Studio install")?;
    let plugins_dir = studio.plugins_path();
    std::fs::create_dir_all(plugins_dir).context("failed to create plugins directory")?;
    let plugin_path = plugins_dir.join("rodeo.rbxm");
    plugin_embed::write_embedded_plugin(&plugin_path.to_string_lossy())
}

/// Write the per-launch RunScript bootstrap to the temp dir. Run by Studio at
/// launch (command-bar identity), it stamps `rodeoSession`/`rodeoPort` onto the
/// Workspace so the static plugin connects to this launch's serve port and
/// reports its session on the WS handshake.
fn write_bootstrap_script(session_guid: &str, port: u16) -> Result<PathBuf> {
    // Absolute path: Studio's working directory differs from rodeo's, so
    // `-runScriptFile` must be absolute (a relative path makes Studio report
    // "Failed to read script file"). current_dir().join avoids the Windows
    // `\\?\` prefix that canonicalize would add.
    let temp_dir = std::env::current_dir()
        .context("failed to resolve current dir")?
        .join(".rodeo/.temp");
    std::fs::create_dir_all(&temp_dir).context("failed to create temp dir")?;
    let path = temp_dir.join(format!("rodeo-bootstrap-{session_guid}.luau"));
    // session_guid is a master-minted UUID (no quotes/backslashes), so embedding
    // it in a string literal is safe.
    let source = format!(
        "local ws = game:GetService(\"Workspace\")\n\
         ws:SetAttribute(\"rodeoSession\", \"{session_guid}\")\n\
         ws:SetAttribute(\"rodeoPort\", {port})\n"
    );
    std::fs::write(&path, source).context("failed to write bootstrap script")?;
    Ok(path)
}

/// Prepare a place file for Studio based on SaveMode. The place contents are
/// never mutated — routing happens at runtime via the RunScript bootstrap, so
/// the original file opens unchanged.
fn prepare_place(place: Option<&str>, save: &SaveMode) -> Result<PathBuf> {
    let temp_dir = Path::new(".rodeo/.temp");
    std::fs::create_dir_all(temp_dir).context("failed to create temp dir")?;

    let has_place = place.is_some_and(|p| !p.is_empty() && Path::new(p).is_file());
    if has_place {
        // Validate up front. The old DOM-parse-and-stamp step implicitly
        // rejected non-place files; without it a corrupted file would copy
        // fine and Studio would hang opening garbage instead of failing fast.
        validate_place_file(place.unwrap())?;
    }

    match save {
        SaveMode::NoSave => {
            // Copy to a temp file so any in-Studio edits never touch the original.
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
            } else {
                let dom = create_minimal_place();
                rbx_control::studio::launch::write_place(&dom, &temp_path)?;
            }
            Ok(temp_path)
        }
        SaveMode::SaveInPlace => {
            if has_place {
                // Open the user's file directly so Studio saves back to it.
                Ok(PathBuf::from(place.unwrap()))
            } else {
                let temp_path = temp_dir.join(format!("rodeo-{}.rbxl", uuid::Uuid::new_v4()));
                let dom = create_minimal_place();
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
            } else {
                let dom = create_minimal_place();
                rbx_control::studio::launch::write_place(&dom, &out_path)?;
            }
            Ok(out_path)
        }
    }
}

/// Create a minimal DataModel with an empty Workspace, for empty-place launches
/// (gives RunScript a file to open).
fn create_minimal_place() -> WeakDom {
    let workspace = InstanceBuilder::new("Workspace");
    WeakDom::new(InstanceBuilder::new("DataModel").with_child(workspace))
}

/// Cheap, read-only sanity check that a path looks like a Roblox place file —
/// binary `rbxl` (magic `<roblox!`) or XML `rbxlx` (`<roblox` / `<?xml`). Just
/// the header, no full DOM parse: enough to fail fast on a corrupted/non-place
/// file rather than hand garbage to Studio and hang waiting for a connection.
fn validate_place_file(path: &str) -> Result<()> {
    use std::io::Read;
    let mut head = [0u8; 8];
    let mut f = std::fs::File::open(path).context("failed to open place file")?;
    let n = f.read(&mut head).context("failed to read place file")?;
    let head = &head[..n];
    if head.starts_with(b"<roblox") || head.starts_with(b"<?xml") {
        Ok(())
    } else {
        bail!("failed to parse place file (not a valid rbxl/rbxlx): {path}");
    }
}
