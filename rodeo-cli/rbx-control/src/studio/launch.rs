//! Generic Roblox Studio process launch.
//!
//! Spawns a single Studio instance (`-task EditPlace` or a place file arg),
//! polls its stdout for the post-login marker, and manages lifecycle —
//! save-on-exit via Cmd+S keystroke, kill on drop, fflag restore. No
//! consumer-specific coupling: no daemon gating, no plugin install,
//! no session-guid stamping. Consumers compose this with their own
//! orchestration.

use anyhow::{bail, Context, Result};
use rbx_dom_weak::{InstanceBuilder, WeakDom};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant, SystemTime};

use crate::fflags::{self, FflagConfig, FflagHandle, FflagTarget};
use crate::studio::layout;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// How to handle the place file on exit.
#[derive(Clone, Debug)]
pub enum SaveMode {
    /// No save — delete temp file on cleanup (default).
    NoSave,
    /// Save in-place — trigger Cmd+S, keep file.
    SaveInPlace,
    /// Save to output path — trigger Cmd+S, keep file at this path.
    SaveToPath(String),
}

/// What place to open in Studio.
#[derive(Clone, Debug)]
pub enum PlaceTarget {
    /// Fresh empty place (caller should pass the temp file path in `PlaceTarget::File`
    /// if they want a prepared place; `Empty` launches Studio with no file).
    Empty,
    /// Local `.rbxl`/`.rbxlx` file. Studio opens this as a local file.
    File(String),
    /// In-memory place bytes (rodeo downloaded them itself for the
    /// multiplayer-test path). Edit-mode launch doesn't support this; caller
    /// should use `File` or `PlaceId` instead.
    Content(Vec<u8>),
    /// Published place by ID. `universe_id` resolved via Roblox API if `None`.
    PlaceId { place_id: u64, universe_id: Option<u64> },
}

/// Options for launching Studio.
#[derive(Clone, Debug, Default)]
pub struct StudioOptions {
    /// Launch without focusing (for parallel/background launches).
    pub background: bool,
    /// How to handle the place file on exit.
    pub save: SaveMode,
    /// FFlag overrides to apply before launch (restored on cleanup).
    pub fflags: FflagConfig,
    /// If true, skip killing Studio on cleanup (Studio survives this process's exit).
    pub detached: bool,
    /// Strip non-essential Studio UI (Explorer/Properties/Toolbox/etc.) by
    /// patching the dock-layout plist before launch. Restored on cleanup.
    pub no_hud: bool,
}

impl Default for SaveMode {
    fn default() -> Self {
        SaveMode::NoSave
    }
}

// ---------------------------------------------------------------------------
// Studio
// ---------------------------------------------------------------------------

/// Handle to a launched Studio instance.
///
/// Owns the process lifecycle, place file, and FFlag restoration. Drop
/// triggers cleanup: save (if configured) → restore fflags → kill → delete
/// temp files. Cleanup is idempotent — safe to call explicit `cleanup()`
/// before the value drops.
pub struct Studio {
    handle: std::sync::Mutex<Option<launch_control::Child>>,
    /// PID stored separately so `kill()` never blocks on the handle mutex
    /// (wait_for_ready holds it during the login gate).
    pid: u32,
    place_path: Option<PathBuf>,
    save_mode: SaveMode,
    fflag_handle: Option<FflagHandle>,
    /// Dock-layout plist patch (`--no-hud`). Restored alongside fflags.
    layout_handle: Option<filepatch::Handle>,
    /// Saved-once flag — cleanup() may be called by both explicit code and Drop.
    saved: AtomicBool,
    /// Cleaned-once flag — guarantees `cleanup()` runs its body only once.
    cleaned: AtomicBool,
    detached: bool,
    launched_at: SystemTime,
}

impl Studio {
    /// Launch a new Studio instance with the given target and options.
    ///
    /// Returns a handle immediately; Studio is still booting. Call
    /// [`Self::wait_for_ready`] after storing the handle to block until
    /// Studio's login flow completes.
    pub fn spawn(target: PlaceTarget, opts: StudioOptions) -> Result<Self> {
        // Apply fflags before launching (Studio reads them at startup).
        let fflag_handle = if !opts.fflags.overrides.is_empty() || opts.fflags.file.is_some() {
            fflags::apply(
                FflagTarget::Studio,
                &opts.fflags.overrides,
                opts.fflags.file.as_deref(),
            )?
        } else {
            None
        };

        tracing::info!(no_hud = opts.no_hud, "Studio::spawn invoked");

        // Apply dock-layout plist patch before launching (Studio reads it at startup).
        let layout_handle = if opts.no_hud {
            let h = layout::apply_no_hud().context("failed to apply --no-hud layout patch")?;
            tracing::info!(applied = h.is_some(), "no-hud: apply_no_hud returned");
            h
        } else {
            None
        };

        let studio_path = studio_application_path()?;

        // `-parentPid` tells Studio to self-exit when the launching process
        // dies. On Windows it also forces a launch mode that does NOT load user
        // plugins — so the rodeo plugin never loads and no VM ever connects.
        // Omit it there and rely on explicit kill-on-drop (+ the JobObject the
        // serve supervisor wraps children in) for teardown. macOS/Linux keep
        // the parent-death behavior.
        #[cfg(target_os = "windows")]
        let parent_args: Vec<String> = Vec::new();
        #[cfg(not(target_os = "windows"))]
        let parent_args: Vec<String> =
            vec!["-parentPid".to_string(), std::process::id().to_string()];

        // Capture the launch time BEFORE spawning. On Windows the bootstrapper
        // creates Studio's log file during the spawn (before launch_control's
        // adopt-the-real-process handoff returns), so a launched_at recorded
        // after spawn() would be *later* than the log's creation — and the log
        // scanner's claim_new_log(launched_at) would then never match it, so
        // process_log stays unresolved and --logs capture produces nothing.
        let launched_at = SystemTime::now();

        match target {
            PlaceTarget::PlaceId { place_id, universe_id } => {
                if !matches!(opts.save, SaveMode::NoSave) {
                    bail!("save modes cannot be used with PlaceId targets (use Studio's publish flow for cloud places)");
                }
                let uid = match universe_id {
                    Some(uid) => uid,
                    None => resolve_universe_id(place_id)?,
                };
                tracing::info!(place_id, universe_id = uid, "launching Studio for place");

                let handle = launch_control::Command::new(&studio_path)
                    .args([
                        "-task", "EditPlace",
                        "-placeId", &place_id.to_string(),
                        "-universeId", &uid.to_string(),
                    ])
                    .args(&parent_args)
                    .background(opts.background)
                    .detached(opts.detached)
                    .stdout(std::process::Stdio::piped())
                    .stderr(std::process::Stdio::piped())
                    .spawn()
                    .context("failed to launch Studio")?;

                let pid = handle.id();
                Ok(Studio {
                    handle: std::sync::Mutex::new(Some(handle)),
                    pid,
                    place_path: None,
                    save_mode: SaveMode::NoSave,
                    fflag_handle,
                    layout_handle,
                    saved: AtomicBool::new(false),
                    cleaned: AtomicBool::new(false),
                    detached: opts.detached,
                    launched_at,
                })
            }
            PlaceTarget::File(ref path) => {
                let place_path = PathBuf::from(path);
                let abs_place = std::fs::canonicalize(&place_path)
                    .unwrap_or_else(|_| std::env::current_dir().unwrap().join(&place_path));
                // Windows `canonicalize` yields an extended-length path
                // (`\\?\C:\...`). Roblox Studio's launcher doesn't recognize
                // that form as a place file to open — it reports "Launch Intent
                // is None" and opens a blank place, so the rodeo plugin's
                // session-guid gate never matches and it never connects. Strip
                // the prefix to a normal absolute path. No-op on macOS/Linux,
                // where the prefix never appears.
                let place_str = abs_place.to_string_lossy().to_string();
                let place_str = place_str
                    .strip_prefix(r"\\?\")
                    .map(str::to_string)
                    .unwrap_or(place_str);

                tracing::info!(place = %place_str, "launching Studio");
                let handle = launch_control::Command::new(&studio_path)
                    .arg(&place_str)
                    .args(&parent_args)
                    .background(opts.background)
                    .detached(opts.detached)
                    // When detached, open the place through the shell so Studio
                    // is rooted at explorer (persistent) rather than the daemon —
                    // otherwise Studio's launcher-watch reaps it when the daemon
                    // dies. No effect when not detached. (File launches only; the
                    // first arg is the place file explorer opens.)
                    .shell_open(true)
                    .stdout(std::process::Stdio::piped())
                    .stderr(std::process::Stdio::piped())
                    .spawn()
                    .context("failed to launch Studio")?;

                let pid = handle.id();
                Ok(Studio {
                    handle: std::sync::Mutex::new(Some(handle)),
                    pid,
                    place_path: Some(place_path),
                    save_mode: opts.save,
                    fflag_handle,
                    layout_handle,
                    saved: AtomicBool::new(false),
                    cleaned: AtomicBool::new(false),
                    detached: opts.detached,
                    launched_at,
                })
            }
            PlaceTarget::Content(_) => {
                bail!("Content variant is for the multiplayer-test flow; use File or PlaceId for edit-mode launch");
            }
            PlaceTarget::Empty => {
                tracing::info!("launching Studio with no place file");
                let handle = launch_control::Command::new(&studio_path)
                    .args(&parent_args)
                    .background(opts.background)
                    .detached(opts.detached)
                    .stdout(std::process::Stdio::piped())
                    .stderr(std::process::Stdio::piped())
                    .spawn()
                    .context("failed to launch Studio")?;

                let pid = handle.id();
                Ok(Studio {
                    handle: std::sync::Mutex::new(Some(handle)),
                    pid,
                    place_path: None,
                    save_mode: opts.save,
                    fflag_handle,
                    layout_handle,
                    saved: AtomicBool::new(false),
                    cleaned: AtomicBool::new(false),
                    detached: opts.detached,
                    launched_at,
                })
            }
        }
    }

    /// Block until Studio's login flow completes. Returns after login is detected
    /// or on a 30s timeout.
    ///
    /// macOS launches Studio under a pty, so the login marker
    /// (`Exit stage 'FetchUserInfo'`) lands on stdout. Windows has no tty, so the
    /// login markers go only to the log file — there we wait on `Authenticated :
    /// YES` in the log instead. Reading the stdout gate on Windows would just burn
    /// its full 30s timeout, holding the daemon launch slot and serializing
    /// parallel launches.
    pub fn wait_for_ready(&self) {
        let pid = self.pid;
        tracing::debug!(pid, "wait_for_ready: waiting on login gate");
        #[cfg(target_os = "macos")]
        {
            let mut handle_guard = self.handle.lock().unwrap();
            if let Some(ref mut handle) = *handle_guard {
                wait_for_login_stdout(handle);
            }
        }
        #[cfg(not(target_os = "macos"))]
        {
            wait_for_login_via_log(self.place_path.as_deref(), self.launched_at);
        }
        tracing::debug!(pid, "wait_for_ready: complete");
    }

    /// Check if Studio process is still running.
    pub fn is_running(&self) -> bool {
        match self.handle.lock().unwrap().as_mut() {
            Some(handle) => handle.try_wait().ok().map_or(true, |s| s.is_none()),
            None => false,
        }
    }

    /// Register a callback invoked when the Studio process exits. Event-driven
    /// (no polling). Forwards directly to `launch_control::Child::on_exit` —
    /// the callback fires once, even if exit already happened.
    pub fn on_exit(&self, callback: impl FnOnce(std::process::ExitStatus) + Send + 'static) {
        if let Some(ref handle) = *self.handle.lock().unwrap() {
            handle.on_exit(callback);
        }
    }

    /// Studio process PID.
    pub fn pid(&self) -> u32 {
        self.pid
    }

    /// Path to the place file Studio opened, if any.
    pub fn place_path(&self) -> Option<&Path> {
        self.place_path.as_deref()
    }

    /// Wall-clock time this Studio was spawned. Useful for pairing with log
    /// files created at startup.
    pub fn launched_at(&self) -> SystemTime {
        self.launched_at
    }

    /// Whether this Studio was launched with `detached: true` — when true,
    /// Drop leaves the process running. Explicit `cleanup()` always kills
    /// regardless.
    pub fn detached(&self) -> bool {
        self.detached
    }

    /// Bring the Studio window to the foreground.
    pub fn focus(&self) -> Result<()> {
        if let Some(ref handle) = *self.handle.lock().unwrap() {
            handle.focus().context("failed to focus Studio")?;
        }
        Ok(())
    }

    /// Send Cmd+S / Ctrl+S to Studio to trigger save. focus() is best-effort —
    /// if it can't confirm we're frontmost, log a warning but still fire the
    /// keystroke. Rationale: the old ("pre-refactor") save path always fired
    /// Cmd+S unconditionally and it usually worked even when we weren't
    /// definitively frontmost. CGEventPostToPSN delivers to the process's
    /// event queue regardless of focus, and many menu dispatchers still
    /// handle the key equivalent.
    pub fn save(&self) -> Result<()> {
        let started = std::time::Instant::now();
        // On Windows, foregrounding happens inside `send_keystroke` under the
        // global keystroke lock. We must NOT pre-focus here: a `focus()` call
        // outside that lock races with a concurrent save's locked injection and
        // steals its foreground mid-chord, dropping the Ctrl+S (the place's
        // mtime never changes and the save hangs to timeout). On macOS,
        // CGEvent delivery wants the window frontmost first and has no
        // foreground-steal race, so keep the pre-focus there.
        #[cfg(target_os = "macos")]
        match self.focus() {
            Ok(()) => tracing::info!(
                pid = self.pid,
                elapsed_ms = started.elapsed().as_millis() as u64,
                "save: focus confirmed",
            ),
            Err(e) => tracing::warn!(
                pid = self.pid,
                "save: focus did not confirm (continuing with keystroke anyway): {e}",
            ),
        }
        let guard = self.handle.lock().unwrap();
        if let Some(ref handle) = *guard {
            tracing::info!(
                pid = handle.id(),
                place = ?self.place_path,
                focus_to_keystroke_ms = started.elapsed().as_millis() as u64,
                "save: sending Cmd+S keystroke",
            );
            // Save shortcut is Cmd+S on macOS, Ctrl+S elsewhere (META is the
            // Windows key on Windows, which would not trigger save).
            #[cfg(target_os = "macos")]
            let save_modifier = launch_control::Modifiers::META;
            #[cfg(not(target_os = "macos"))]
            let save_modifier = launch_control::Modifiers::CONTROL;
            let ks_result = handle
                .send_keystroke(launch_control::Code::KeyS, save_modifier);
            match &ks_result {
                Ok(()) => tracing::info!(pid = handle.id(), "save: send_keystroke returned Ok"),
                Err(e) => tracing::warn!(pid = handle.id(), "save: send_keystroke failed: {e}"),
            }
            ks_result.context("failed to send save keystroke to Studio")?;
            Ok(())
        } else {
            tracing::error!("save: no Studio handle available");
            bail!("no Studio handle available for save")
        }
    }

    /// Terminate the Studio process.
    /// Uses stored PID directly so it never blocks on the handle mutex.
    pub fn kill(&self) {
        #[cfg(unix)]
        unsafe {
            libc::kill(self.pid as i32, libc::SIGKILL);
        }
        #[cfg(not(unix))]
        if let Some(ref mut handle) = *self.handle.lock().unwrap() {
            let _ = handle.kill();
        }
    }

    /// Full cleanup: save (if configured and not yet saved) → restore fflags →
    /// kill → delete temp place file (if NoSave). Idempotent.
    ///
    /// Always kills the Studio process — the `detached` option only governs
    /// what happens when the `Studio` handle is dropped (without an explicit
    /// cleanup call). Calling this function is interpreted as the caller
    /// taking down the process.
    pub fn cleanup(&self) {
        if self.cleaned.swap(true, Ordering::Relaxed) {
            return;
        }

        // Save (one shot): trigger Cmd+S and wait for mtime change
        if !matches!(self.save_mode, SaveMode::NoSave)
            && !self.saved.swap(true, Ordering::Relaxed)
            && self.is_running()
        {
            tracing::info!("Saving Studio place...");
            let mtime_before = self
                .place_path
                .as_ref()
                .and_then(|p| std::fs::metadata(p).ok())
                .and_then(|m| m.modified().ok());

            if let Err(e) = self.save() {
                tracing::error!("Save failed: {e}");
            } else if let (Some(ref path), Some(before)) = (&self.place_path, mtime_before) {
                tracing::debug!(path = %path.display(), mtime_before = ?before, "waiting for save");
                let deadline = Instant::now() + Duration::from_secs(30);
                loop {
                    std::thread::sleep(Duration::from_millis(200));
                    if Instant::now() > deadline {
                        tracing::warn!("Save timed out after 30s");
                        break;
                    }
                    if let Ok(meta) = std::fs::metadata(path) {
                        if let Ok(now) = meta.modified() {
                            if now != before {
                                tracing::info!("Save complete");
                                break;
                            }
                        }
                    } else {
                        tracing::warn!("Place file disappeared during save poll");
                        break;
                    }
                }
            } else {
                std::thread::sleep(Duration::from_secs(2));
            }
        }

        // Restore fflags (always — system-wide state).
        if let Some(ref handle) = self.fflag_handle {
            handle.restore();
        }

        // Restore Studio dock-layout plist patch (--no-hud).
        if let Some(ref handle) = self.layout_handle {
            handle.restore();
        }

        self.kill();
        // Only delete the place file when not saving (it was a temp).
        if matches!(self.save_mode, SaveMode::NoSave) {
            if let Some(ref path) = self.place_path {
                let _ = std::fs::remove_file(path);
                let lock_path = path.with_file_name(format!(
                    "{}.lock",
                    path.file_name().unwrap_or_default().to_string_lossy()
                ));
                let _ = std::fs::remove_file(lock_path);
            }
        }
    }
}

impl Drop for Studio {
    fn drop(&mut self) {
        tracing::debug!(pid = self.pid, detached = self.detached, "rbx_control::Studio::Drop");
        if self.detached {
            // Caller asked Studio to survive parent exit. Restore system-wide
            // state (fflags, layout plist) so we don't leak overrides, but
            // leave the Studio process running and don't delete its place file.
            // Explicit `cleanup()` calls bypass this and always tear down.
            if !self.cleaned.swap(true, Ordering::Relaxed) {
                if let Some(ref handle) = self.fflag_handle { handle.restore(); }
                if let Some(ref handle) = self.layout_handle { handle.restore(); }
            }
        } else {
            self.cleanup();
        }
    }
}

// ---------------------------------------------------------------------------
// Place helpers
// ---------------------------------------------------------------------------

/// Create a minimal empty place DOM (DataModel + Workspace).
pub fn create_minimal_place() -> WeakDom {
    let mut dom = WeakDom::new(InstanceBuilder::new("DataModel"));
    let root = dom.root_ref();
    let workspace = InstanceBuilder::new("Workspace");
    dom.insert(root, workspace);
    dom
}

/// Serialize a `WeakDom` to `.rbxl` binary format.
pub fn serialize_place(dom: &WeakDom) -> Result<Vec<u8>> {
    let mut buf = Vec::new();
    rbx_binary::to_writer(&mut buf, dom, dom.root().children())
        .context("failed to serialize place")?;
    Ok(buf)
}

/// Write a DOM to a place file, choosing binary (`.rbxl`) or XML (`.rbxlx`) format
/// based on the file extension.
pub fn write_place(dom: &WeakDom, path: &Path) -> Result<()> {
    let refs = dom.root().children();
    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
    if ext == "rbxlx" {
        let mut buf = Vec::new();
        let options = rbx_xml::EncodeOptions::new()
            .property_behavior(rbx_xml::EncodePropertyBehavior::WriteUnknown);
        rbx_xml::to_writer(&mut buf, dom, refs, options)
            .context("failed to serialize XML place")?;
        std::fs::write(path, buf).context("failed to write place file")
    } else {
        let mut buf = Vec::new();
        rbx_binary::to_writer(&mut buf, dom, refs)
            .context("failed to serialize binary place")?;
        std::fs::write(path, buf).context("failed to write place file")
    }
}

// ---------------------------------------------------------------------------
// Universe ID resolution
// ---------------------------------------------------------------------------

/// Resolve a place ID to its universe ID via the public Roblox API.
pub fn resolve_universe_id(place_id: u64) -> Result<u64> {
    let url = format!("https://apis.roblox.com/universes/v1/places/{place_id}/universe");
    let resp = reqwest::blocking::get(&url).context("failed to reach Roblox API")?;
    if !resp.status().is_success() {
        bail!(
            "Roblox API returned {} for place {place_id} — verify the place ID exists and is published",
            resp.status()
        );
    }
    let body: serde_json::Value = resp.json().context("failed to parse Roblox API response")?;
    body["universeId"]
        .as_u64()
        .context("Roblox API response missing universeId")
}

// ---------------------------------------------------------------------------
// Studio binary discovery
// ---------------------------------------------------------------------------

/// Path to the Roblox Studio application.
/// On macOS, returns the `.app` bundle path (for `NSWorkspace`).
/// On Windows, returns the executable path.
pub fn studio_application_path() -> Result<String> {
    let studio =
        roblox_install::RobloxStudio::locate().context("could not locate Roblox Studio")?;

    #[cfg(target_os = "macos")]
    {
        let app_path = studio
            .application_path()
            .ancestors()
            .find(|p| p.extension().is_some_and(|e| e == "app"))
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_else(|| studio.application_path().to_string_lossy().to_string());
        Ok(app_path)
    }

    #[cfg(not(target_os = "macos"))]
    {
        Ok(studio.application_path().to_string_lossy().to_string())
    }
}

/// Path to the Roblox Studio `content/` directory, if available.
pub fn studio_content_path() -> Option<String> {
    roblox_install::RobloxStudio::locate()
        .ok()
        .map(|s| s.content_path().to_string_lossy().to_string())
}

// ---------------------------------------------------------------------------
// Login gate: detect login completion
// ---------------------------------------------------------------------------

/// macOS: wait for Studio to finish its login flow by scanning stdout.
/// Returns on the `Exit stage 'FetchUserInfo'` marker or 30s timeout.
///
/// Pipes are auto-drained by `launch_control`'s background threads; no manual
/// drain needed.
#[cfg(target_os = "macos")]
pub fn wait_for_login_stdout(child: &mut launch_control::Child) {
    let stdout = match child.stdout.as_ref() {
        Some(stdout) => stdout,
        None => {
            tracing::debug!("login gate: no stdout channel available");
            return;
        }
    };

    let deadline = Instant::now() + Duration::from_secs(30);

    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        if remaining.is_zero() {
            tracing::debug!("login gate: timeout waiting for FetchUserInfo");
            return;
        }

        match stdout.recv_timeout(remaining) {
            Ok(line) => {
                if line.contains("Exit stage 'FetchUserInfo'") {
                    tracing::debug!("login gate: FetchUserInfo completed");
                    return;
                }
            }
            Err(_) => {
                tracing::debug!("login gate: stdout channel closed");
                return;
            }
        }
    }
}

/// Windows (and other non-macOS): Studio has no tty, so its login markers go only
/// to the log file. Wait for `Authenticated : YES` in the Studio's own log.
/// Returns when login completes or after a 30s timeout. The Studio's log is
/// identified by the unique temp place filename echoed in the log's command-line
/// header (robust under concurrent launches); with no place file (PlaceId
/// targets) fall back to the newest log created at/after `launched_at`.
#[cfg(not(target_os = "macos"))]
fn wait_for_login_via_log(place_path: Option<&Path>, launched_at: SystemTime) {
    let logs_dir = match crate::paths::roblox_logs_dir() {
        Some(d) => d,
        None => {
            tracing::debug!("login gate(log): no Roblox logs dir");
            return;
        }
    };
    let deadline = Instant::now() + Duration::from_secs(30);
    let since = launched_at
        .checked_sub(Duration::from_secs(5))
        .unwrap_or(launched_at);
    let id_marker = place_path
        .and_then(|p| p.file_name())
        .and_then(|n| n.to_str())
        .map(|s| s.to_string());

    // Phase 1: locate our Studio's log.
    let log = loop {
        if let Some(p) = find_login_log(&logs_dir, since, id_marker.as_deref()) {
            break p;
        }
        if Instant::now() >= deadline {
            tracing::debug!("login gate(log): timeout locating Studio log");
            return;
        }
        std::thread::sleep(Duration::from_millis(200));
    };

    // Phase 2: wait for login completion.
    loop {
        if let Ok(content) = std::fs::read_to_string(&log) {
            if content.contains("Authenticated : YES") {
                tracing::debug!("login gate(log): authenticated");
                return;
            }
        }
        if Instant::now() >= deadline {
            tracing::debug!("login gate(log): timeout waiting for Authenticated");
            return;
        }
        std::thread::sleep(Duration::from_millis(200));
    }
}

/// Find the `*_Studio_*_last.log` for our launch: if `id_marker` is set (the temp
/// place filename), require the log's contents to contain it; otherwise take the
/// newest log modified at/after `since`.
#[cfg(not(target_os = "macos"))]
fn find_login_log(logs_dir: &Path, since: SystemTime, id_marker: Option<&str>) -> Option<PathBuf> {
    let mut best: Option<(SystemTime, PathBuf)> = None;
    for entry in std::fs::read_dir(logs_dir).ok()?.flatten() {
        let path = entry.path();
        let name = match path.file_name().and_then(|n| n.to_str()) {
            Some(n) => n,
            None => continue,
        };
        if !name.contains("_Studio_") || !name.ends_with("_last.log") {
            continue;
        }
        let mtime = match entry.metadata().and_then(|m| m.modified()) {
            Ok(t) => t,
            Err(_) => continue,
        };
        if mtime < since {
            continue;
        }
        match id_marker {
            Some(marker) => {
                if let Ok(content) = std::fs::read_to_string(&path) {
                    if content.contains(marker)
                        && best.as_ref().map_or(true, |(t, _)| mtime > *t)
                    {
                        best = Some((mtime, path));
                    }
                }
            }
            None => {
                if best.as_ref().map_or(true, |(t, _)| mtime > *t) {
                    best = Some((mtime, path));
                }
            }
        }
    }
    best.map(|(_, p)| p)
}
