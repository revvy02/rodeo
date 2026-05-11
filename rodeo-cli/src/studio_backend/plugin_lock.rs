//! Studio plugin file lifecycle: sweep + lock.
//!
//! Each studio-backend process installs zero or more rodeo plugin files into
//! the user's Roblox `Plugins/` dir, named `rodeo-{port}-{session_guid}.rbxm`.
//! In the happy path, [`crate::studio_backend::Studio::cleanup`] deletes the
//! plugin when its Studio instance exits. But Drop only runs on graceful
//! shutdown — SIGKILL, OOM, panic-abort, `process::exit`, kernel panic, and
//! power loss all skip it, leaving stale `.rbxm` files in the plugins dir
//! that Studio will load on next launch (and fail to use, since their
//! backend is gone).
//!
//! Fix: at studio-backend startup, sweep stale plugin files. Liveness is
//! determined by a sibling lockfile `rodeo-{port}.lock` held with `fd-lock`
//! (BSD `flock` on Unix, `LockFileEx` on Windows) for the studio-backend's
//! lifetime. The kernel auto-releases the lock when the process terminates
//! *for any reason*, including SIGKILL — that's the property we depend on.
//! Any unheld lock means the owning backend is dead, and its plugin files
//! are stale.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use anyhow::{Context, Result};

const PLUGIN_PREFIX: &str = "rodeo-";
const PLUGIN_SUFFIX: &str = ".rbxm";
const LOCK_SUFFIX: &str = ".lock";

/// Scan the Roblox plugins dir for `rodeo-{port}-{session_guid}.rbxm` files
/// whose owning studio-backend (identified by `rodeo-{port}.lock`) is no
/// longer alive, and delete them. Run once at studio-backend startup,
/// *before* installing this backend's own plugin or acquiring its lock.
///
/// Failures (missing dir, permission denied) are logged at debug and
/// swallowed — sweep is best-effort cleanup, never fatal.
pub fn sweep_stale_plugins() {
    let Ok(plugins_dir) = plugins_dir() else {
        tracing::debug!("plugin sweep: could not locate Roblox plugins dir");
        return;
    };
    if !plugins_dir.exists() {
        return;
    }

    // Group every rodeo-related file (plugin .rbxm and lock .lock) by
    // port so we only check each port's lock once. We have to consider
    // lock files as well as plugin files: a backend that died before
    // installing its first plugin still left a .lock behind.
    let mut by_port: HashMap<u16, Vec<PathBuf>> = HashMap::new();
    let entries = match fs::read_dir(&plugins_dir) {
        Ok(it) => it,
        Err(e) => {
            tracing::debug!("plugin sweep: read_dir failed: {e}");
            return;
        }
    };
    for entry in entries.flatten() {
        let name = entry.file_name();
        let Some(name) = name.to_str() else { continue };
        if let Some(port) = parse_plugin_port(name).or_else(|| parse_lock_port(name)) {
            by_port.entry(port).or_default().push(entry.path());
        }
    }

    for (port, files) in by_port {
        let lock_path = lock_path(&plugins_dir, port);
        if lock_held(&lock_path) {
            // Owning backend is alive — leave its files alone.
            continue;
        }
        for p in &files {
            match fs::remove_file(p) {
                Ok(()) => tracing::info!(path = %p.display(), "plugin sweep: removed stale file"),
                Err(e) => tracing::debug!(path = %p.display(), "plugin sweep: remove failed: {e}"),
            }
        }
    }
}

/// Acquire the lockfile for this studio-backend's port. The lock is held
/// for the rest of the process's lifetime — the underlying file handle is
/// `mem::forget`'d so Drop never closes it; the kernel releases the lock
/// when the process terminates (graceful or not).
///
/// Errors if the lock is already held — meaning another rodeo studio-backend
/// is alive on this port. (This shouldn't usually happen since the same
/// port can't be bound twice, but it surfaces a sane error if it does.)
pub fn acquire_lock(port: u16) -> Result<()> {
    let plugins_dir = plugins_dir().context("locate Roblox plugins dir")?;
    fs::create_dir_all(&plugins_dir).context("create plugins dir")?;
    let path = lock_path(&plugins_dir, port);

    let file = fs::OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(&path)
        .with_context(|| format!("open {}", path.display()))?;

    // Box::leak so the RwLock (and the FD it owns) live for 'static. The
    // guard borrows from the leaked lock; we mem::forget the guard so its
    // Drop doesn't release. Net effect: lock is held until process death,
    // at which point the kernel releases automatically.
    let lock: &'static mut fd_lock::RwLock<fs::File> =
        Box::leak(Box::new(fd_lock::RwLock::new(file)));
    let guard = lock.try_write().with_context(|| {
        format!(
            "plugin lock {} already held — is another rodeo studio-backend on port {port}?",
            path.display()
        )
    })?;
    std::mem::forget(guard);
    tracing::debug!(path = %path.display(), "plugin sweep: acquired lock");
    Ok(())
}

fn plugins_dir() -> Result<PathBuf> {
    let studio = roblox_install::RobloxStudio::locate()
        .context("locate Roblox Studio install")?;
    Ok(studio.plugins_path().to_path_buf())
}

fn lock_path(plugins_dir: &Path, port: u16) -> PathBuf {
    plugins_dir.join(format!("{PLUGIN_PREFIX}{port}{LOCK_SUFFIX}"))
}

/// Parse `rodeo-{port}-{session_guid}.rbxm` → `port`. Returns None for
/// non-rodeo files or rodeo lockfiles.
fn parse_plugin_port(filename: &str) -> Option<u16> {
    let stem = filename.strip_suffix(PLUGIN_SUFFIX)?;
    let after_prefix = stem.strip_prefix(PLUGIN_PREFIX)?;
    let dash = after_prefix.find('-')?;
    after_prefix[..dash].parse().ok()
}

/// Parse `rodeo-{port}.lock` → `port`. Returns None for plugin files and
/// non-rodeo files.
fn parse_lock_port(filename: &str) -> Option<u16> {
    let stem = filename.strip_suffix(LOCK_SUFFIX)?;
    let port_str = stem.strip_prefix(PLUGIN_PREFIX)?;
    port_str.parse().ok()
}

fn lock_held(path: &Path) -> bool {
    let Ok(file) = fs::OpenOptions::new().write(true).open(path) else {
        // No lockfile = no holder. Treat plugin as orphaned.
        return false;
    };
    let mut lock = fd_lock::RwLock::new(file);
    // try_write returns Err if someone else holds the lock; Ok if we got
    // it (we drop the guard immediately) — held by us during this scope
    // means held by no one else, so we report unheld.
    let held = lock.try_write().is_err();
    held
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_plugin_port_strips_session_guid() {
        assert_eq!(parse_plugin_port("rodeo-44870-abc-def.rbxm"), Some(44870));
        assert_eq!(parse_plugin_port("rodeo-1-x.rbxm"), Some(1));
    }

    #[test]
    fn parse_plugin_port_rejects_non_matches() {
        assert_eq!(parse_plugin_port("rodeo-44870.lock"), None);
        assert_eq!(parse_plugin_port("not-a-plugin.rbxm"), None);
        assert_eq!(parse_plugin_port("rodeo-noport.rbxm"), None);
        assert_eq!(parse_plugin_port("rodeo-44870.rbxm"), None); // no session_guid
    }

    #[test]
    fn parse_lock_port_matches_lockfiles_only() {
        assert_eq!(parse_lock_port("rodeo-44870.lock"), Some(44870));
        assert_eq!(parse_lock_port("rodeo-44870-session.rbxm"), None);
        assert_eq!(parse_lock_port("not-rodeo.lock"), None);
    }
}
