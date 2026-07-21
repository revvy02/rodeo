use anyhow::{Context, Result};
use serde_json::{json, Map, Value};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

const SETTINGS_FILE: &str = "ClientAppSettings.json";

const KNOWN_PREFIXES: &[&str] = &[
    "DFFlag", "SFFlag", "FFlag", "DFInt", "FInt", "DFString", "SFString", "FString", "DFLog",
    "FLog",
];

/// Which application's FFlags to modify.
pub enum FflagTarget {
    Studio,
    Player,
}

/// FFlag configuration for a Studio or Player launch.
#[derive(Clone, Debug, Default)]
pub struct FflagConfig {
    pub overrides: Vec<String>,
    pub file: Option<String>,
}

/// Revert a **stale** ClientAppSettings.json patch for the given target — one
/// left behind by a `--profile` (or any fflag) run that was killed before its
/// restore ran. Without this, a leaked patch (e.g. the microprofiler
/// autocapture FFlag) stays enabled for *every* future Studio launch and
/// silently fills the disk with capture dumps. Only reverts locks whose owner
/// process is dead; an active patch from a concurrent run is left alone.
/// Returns the number reverted. Safe to call on every startup.
pub fn sweep_stale_leak(target: FflagTarget) -> Result<usize> {
    let settings_path = client_settings_dir(&target)?.join(SETTINGS_FILE);
    let n = filepatch::sweep_stale(&settings_path, crate::pid_alive)?;
    if n > 0 {
        tracing::warn!(
            "swept {n} stale fflag lock(s) — reverted a leaked patch at {}",
            settings_path.display()
        );
    }
    Ok(n)
}

/// Resolve the ClientSettings directory for the given target.
fn client_settings_dir(target: &FflagTarget) -> Result<PathBuf> {
    match target {
        FflagTarget::Studio => {
            let studio = roblox_install::RobloxStudio::locate()
                .context("could not locate Roblox Studio")?;
            let exe_dir = studio
                .application_path()
                .parent()
                .context("cannot determine Studio directory")?;
            Ok(exe_dir.join("ClientSettings"))
        }
        FflagTarget::Player => {
            let dir = player_exe_dir().context("could not locate Roblox Player")?;
            Ok(dir.join("ClientSettings"))
        }
    }
}

/// Locate the Roblox Player executable directory.
fn player_exe_dir() -> Result<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        let path = PathBuf::from("/Applications/Roblox.app/Contents/MacOS");
        if path.exists() {
            Ok(path)
        } else {
            anyhow::bail!("Roblox Player not found at /Applications/Roblox.app")
        }
    }

    #[cfg(target_os = "windows")]
    {
        let local_app = std::env::var("LOCALAPPDATA").context("LOCALAPPDATA not set")?;
        let versions_dir = PathBuf::from(local_app).join("Roblox").join("Versions");
        let mut latest: Option<PathBuf> = None;
        if let Ok(entries) = std::fs::read_dir(&versions_dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.join("RobloxPlayerBeta.exe").exists() {
                    latest = Some(p);
                }
            }
        }
        latest.context("could not find Roblox Player in Versions directory")
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        anyhow::bail!("Roblox Player location not supported on this platform")
    }
}

fn has_known_prefix(key: &str) -> bool {
    KNOWN_PREFIXES.iter().any(|p| key.starts_with(p))
}

/// Auto-prefix a bare key based on value type.
/// `EnableLoadModule=true` → `FFlagEnableLoadModule`
fn auto_prefix(key: &str, value: &Value) -> String {
    if has_known_prefix(key) {
        return key.to_string();
    }
    let prefix = match value {
        Value::Bool(_) => "FFlag",
        Value::Number(_) => "FInt",
        _ => "FString",
    };
    format!("{prefix}{key}")
}

fn parse_value(s: &str) -> Value {
    match s {
        "true" => json!(true),
        "false" => json!(false),
        _ => match s.parse::<i64>() {
            Ok(n) => json!(n),
            Err(_) => json!(s),
        },
    }
}

fn parse_overrides(overrides: &[String]) -> Map<String, Value> {
    let mut map = Map::new();
    for arg in overrides {
        if let Some((key, val_str)) = arg.split_once('=') {
            let value = parse_value(val_str);
            let prefixed_key = auto_prefix(key, &value);
            map.insert(prefixed_key, value);
        } else {
            tracing::warn!("invalid --fflag.override format: '{arg}' (expected Key=Value)");
        }
    }
    map
}

fn load_file(path: &str) -> Result<Map<String, Value>> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("failed to read fflag file: {path}"))?;
    let parsed: Value = serde_json::from_str(&content)
        .with_context(|| format!("failed to parse fflag file: {path}"))?;
    match parsed {
        Value::Object(map) => Ok(map),
        _ => anyhow::bail!("fflag file must contain a JSON object: {path}"),
    }
}

/// Handle to an applied FFlag modification. Restores the original on drop;
/// additionally removes the ClientSettings directory if we created it during apply.
pub struct FflagHandle {
    inner: filepatch::Handle,
    /// Directory to remove on restore if we created it during apply. Only
    /// removed if empty.
    created_dir: Option<PathBuf>,
    restored: AtomicBool,
}

impl FflagHandle {
    /// Restore the original ClientAppSettings.json. Idempotent.
    pub fn restore(&self) {
        if self.restored.swap(true, Ordering::SeqCst) {
            return;
        }
        self.inner.restore();
        if let Some(ref dir) = self.created_dir {
            // Best-effort rmdir — only succeeds if the directory is empty.
            let _ = std::fs::remove_dir(dir);
        }
    }
}

impl Drop for FflagHandle {
    fn drop(&mut self) {
        self.restore();
    }
}

/// Apply FFlag overrides to the ClientAppSettings.json for the given target.
///
/// Returns a handle that restores the original on cleanup, or None if no flags were specified.
pub fn apply(
    target: FflagTarget,
    fflag_overrides: &[String],
    fflag_file: Option<&str>,
) -> Result<Option<FflagHandle>> {
    // Build merged flag map: file first, then CLI overrides on top.
    let mut flags = Map::new();
    if let Some(path) = fflag_file {
        flags.extend(load_file(path)?);
    }
    flags.extend(parse_overrides(fflag_overrides));

    if flags.is_empty() {
        return Ok(None);
    }

    let cs_dir = client_settings_dir(&target)?;
    let settings_path = cs_dir.join(SETTINGS_FILE);

    // Create ClientSettings/ if missing — remember so we can clean it up on restore.
    let created_dir = if !cs_dir.exists() {
        std::fs::create_dir_all(&cs_dir).context("failed to create ClientSettings directory")?;
        Some(cs_dir.clone())
    } else {
        None
    };

    // Delegate lock/backup/restore mechanics to filepatch; supply merge strategy here.
    let handle = filepatch::apply(&settings_path, |orig: Option<&[u8]>| {
        // Parse backed-up original (if any), tolerating malformed JSON by
        // starting fresh rather than aborting.
        let mut merged: Map<String, Value> = match orig {
            Some(bytes) => match serde_json::from_slice::<Value>(bytes) {
                Ok(Value::Object(map)) => map,
                _ => {
                    tracing::warn!("existing ClientAppSettings.json is malformed; overwriting");
                    Map::new()
                }
            },
            None => Map::new(),
        };
        for (k, v) in flags.iter() {
            merged.insert(k.clone(), v.clone());
        }
        let pretty = serde_json::to_string_pretty(&Value::Object(merged))
            .context("failed to serialize fflags")?;
        Ok(pretty.into_bytes())
    })?;

    let flag_count = fflag_overrides.len() + fflag_file.map(|_| 1).unwrap_or(0);
    tracing::info!(
        "applied {flag_count} fflag source(s) to {}",
        settings_path.display()
    );

    Ok(Some(FflagHandle {
        inner: handle,
        created_dir,
        restored: AtomicBool::new(false),
    }))
}
