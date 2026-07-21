//! Atomic file patch with rename-as-backup and RAII restore.
//!
//! # Semantics
//!
//! [`apply`] takes a path and a closure. It:
//! 1. Renames the current file at `path` to a UUID-suffixed lock file
//!    (`<basename>.lock.<uuid>`) — or creates an empty sentinel lock if the
//!    file didn't exist.
//! 2. Hands the closure the pre-rename content (or `None` for sentinel).
//! 3. Writes the closure's return value to `path`.
//! 4. Returns a [`Handle`]. On [`Handle::drop`], the lock is renamed back and
//!    the patched file is removed — restoring the original byte-for-byte.
//!
//! # Concurrent safety
//!
//! If a lock file already exists when [`apply`] is called (either because
//! another process has an active patch, or a previous process crashed without
//! restoring), the new call *claims* it by renaming it to its own UUID.
//! It then reads the backed-up original from the claimed lock and produces
//! the new content. This is "last writer wins" for the `path` content; the
//! original is preserved through the chain of ownership.
//!
//! Crash recovery is free: stale locks from dead processes get adopted by the
//! next caller, who will restore them when their own handle drops.
//!
//! That adoption only fires when someone re-patches the *same* path, though. If
//! nothing re-patches it, a leaked patch persists indefinitely (e.g. a killed
//! `--profile` run leaves Studio's autocapture FFlag enabled forever). For that
//! case, lock files embed the owner's **pid** (`<base>.lock.<pid>.<uuid>`) and
//! [`sweep_stale`] reverts any lock whose owner is no longer alive — call it on
//! startup to self-heal leaks without needing a fresh patch.
//!
//! # What this crate does *not* do
//!
//! - It does not understand file formats. JSON merges, plist key replacement,
//!   etc. live in the caller's closure.
//! - It does not block third-party processes. POSIX locks are advisory; this
//!   crate does not try to enforce exclusive access against uncooperative
//!   readers/writers. Use cases where the target app writes the file during
//!   the lease will have those writes clobbered on restore — which is often
//!   the desired behavior (e.g. Studio rewriting its layout plist on exit).

use anyhow::{Context, Result};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use tracing::debug;

const LOCK_INFIX: &str = ".lock.";

/// A live patch. The original file is restored when the handle is dropped.
/// Use [`Handle::restore`] to trigger restore explicitly; it is idempotent.
pub struct Handle {
    /// The UUID-suffixed lock file that holds the backed-up original content
    /// (or is a zero-byte sentinel if no original existed).
    lock_path: PathBuf,
    /// The path that was patched — where restored content will be written.
    target_path: PathBuf,
    /// When true, lock file is a sentinel and restore just deletes the patch
    /// without renaming anything back.
    no_original: bool,
    /// Ensures restore runs at most once across manual call + Drop.
    restored: AtomicBool,
}

impl Handle {
    /// Restore the original file. Safe to call multiple times; only the first
    /// call has an effect.
    ///
    /// If the lock has been claimed by another process (lock file no longer
    /// exists at our UUID), this is a no-op — that process owns the restore.
    pub fn restore(&self) {
        if self.restored.swap(true, Ordering::SeqCst) {
            return;
        }
        if !self.lock_path.exists() {
            // Another process claimed our lock; they'll restore.
            return;
        }

        let _ = std::fs::remove_file(&self.target_path);

        if self.no_original {
            let _ = std::fs::remove_file(&self.lock_path);
        } else if let Err(e) = std::fs::rename(&self.lock_path, &self.target_path) {
            tracing::warn!(
                "filepatch: failed to restore {} from {}: {e}",
                self.target_path.display(),
                self.lock_path.display(),
            );
        }
        debug!(target = %self.target_path.display(), "filepatch: restored");
    }
}

impl Drop for Handle {
    fn drop(&mut self) {
        self.restore();
    }
}

/// Build the lock filename `<basename>.lock.<pid>.<uuid>` next to `path`. The
/// pid identifies the owning process so [`sweep_stale`] can tell a live patch
/// from a leaked one.
fn lock_path_for(path: &Path, pid: u32, uuid: &str) -> PathBuf {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let base = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    dir.join(format!("{base}{LOCK_INFIX}{pid}.{uuid}"))
}

/// Parse the owner pid out of a lock filename `<base>.lock.<pid>.<uuid>`.
/// Returns `None` for an old (pre-pid) lock, which callers treat as stale.
fn pid_from_lock(lock_path: &Path, base: &str) -> Option<u32> {
    let name = lock_path.file_name()?.to_str()?;
    let rest = name.strip_prefix(&format!("{base}{LOCK_INFIX}"))?;
    // pid is the segment before the first '.' (uuid has no dots).
    rest.split('.').next()?.parse::<u32>().ok()
}

/// Find any existing `<basename>.lock.*` file in the same directory as `path`.
///
/// Used to detect a prior patch (either an active one from another process or
/// a stale one from a crashed process) so we can claim it via rename.
fn find_existing_lock(path: &Path) -> Option<PathBuf> {
    find_locks(path).into_iter().next().map(|(p, _)| p)
}

/// List every `<basename>.lock.*` file for `path` with its embedded owner pid
/// (`None` if the lock predates pid-tagging).
pub fn find_locks(path: &Path) -> Vec<(PathBuf, Option<u32>)> {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let Some(base) = path.file_name().and_then(|n| n.to_str()) else {
        return Vec::new();
    };
    let prefix = format!("{base}{LOCK_INFIX}");
    let mut out = Vec::new();
    if let Ok(rd) = std::fs::read_dir(dir) {
        for entry in rd.flatten() {
            if entry
                .file_name()
                .to_str()
                .map_or(false, |n| n.starts_with(&prefix))
            {
                let p = entry.path();
                let pid = pid_from_lock(&p, base);
                out.push((p, pid));
            }
        }
    }
    out
}

/// Revert a leaked patch directly from its lock file, without a [`Handle`].
/// Mirrors [`Handle::restore`]: an empty (sentinel) lock means the original
/// didn't exist, so the patched target is deleted; otherwise the lock is
/// renamed back over the target. No-op if the lock is already gone.
fn restore_from_lock(lock_path: &Path, target: &Path) -> Result<()> {
    if !lock_path.exists() {
        return Ok(());
    }
    let is_sentinel = std::fs::metadata(lock_path).map(|m| m.len() == 0).unwrap_or(false);
    let _ = std::fs::remove_file(target);
    if is_sentinel {
        let _ = std::fs::remove_file(lock_path);
    } else {
        std::fs::rename(lock_path, target).with_context(|| {
            format!(
                "restore {} from {}",
                target.display(),
                lock_path.display()
            )
        })?;
    }
    debug!(target = %target.display(), "filepatch: swept stale lock");
    Ok(())
}

/// Revert any **stale** patch on `path` — one whose owning process is no longer
/// alive per `is_alive(pid)`. Locks with a live owner (an active patch from a
/// concurrent process) are left untouched. A lock with no parseable pid
/// (pre-pid-tagging) is treated as stale. Returns the number of locks reverted.
///
/// Call on startup to self-heal a leaked patch left by a crashed/hard-killed
/// run, without needing to re-patch the file.
pub fn sweep_stale<F: Fn(u32) -> bool>(path: &Path, is_alive: F) -> Result<usize> {
    let mut reverted = 0;
    for (lock_path, pid) in find_locks(path) {
        let stale = pid.map_or(true, |p| !is_alive(p));
        if stale {
            restore_from_lock(&lock_path, path)?;
            reverted += 1;
        }
    }
    Ok(reverted)
}

/// Apply a patch.
///
/// - `path` is the file to patch.
/// - `build` is called with `Some(&[u8])` = current original content, or
///   `None` if no original existed. Its return value is written to `path`.
///
/// Returns a [`Handle`]; drop it to restore the original.
pub fn apply<F>(path: &Path, build: F) -> Result<Handle>
where
    F: FnOnce(Option<&[u8]>) -> Result<Vec<u8>>,
{
    let owner_uuid = uuid::Uuid::new_v4().to_string();
    let lock_path = lock_path_for(path, std::process::id(), &owner_uuid);

    // Determine the starting state: is there an existing lock to claim, an
    // existing target file to move aside, or nothing?
    let no_original = if let Some(existing) = find_existing_lock(path) {
        std::fs::rename(&existing, &lock_path).with_context(|| {
            format!(
                "claim existing lock: {} -> {}",
                existing.display(),
                lock_path.display(),
            )
        })?;
        std::fs::metadata(&lock_path)
            .map(|m| m.len() == 0)
            .unwrap_or(true)
    } else if path.exists() {
        std::fs::rename(path, &lock_path)
            .with_context(|| format!("back up {} -> {}", path.display(), lock_path.display()))?;
        false
    } else {
        std::fs::write(&lock_path, b"")
            .with_context(|| format!("write sentinel lock: {}", lock_path.display()))?;
        true
    };

    // Produce the new content via the caller's closure.
    let original_bytes: Option<Vec<u8>> = if no_original {
        None
    } else {
        Some(
            std::fs::read(&lock_path)
                .with_context(|| format!("read backed-up original: {}", lock_path.display()))?,
        )
    };
    let new_content = build(original_bytes.as_deref()).context("patch builder failed")?;

    std::fs::write(path, &new_content)
        .with_context(|| format!("write patched {}", path.display()))?;

    debug!(target = %path.display(), lock = %lock_path.display(), "filepatch: applied");

    Ok(Handle {
        lock_path,
        target_path: path.to_path_buf(),
        no_original,
        restored: AtomicBool::new(false),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    struct TempDir(PathBuf);
    impl TempDir {
        fn new() -> Self {
            let p = std::env::temp_dir().join(format!("filepatch-test-{}", uuid::Uuid::new_v4()));
            std::fs::create_dir_all(&p).unwrap();
            Self(p)
        }
        fn path(&self) -> &Path {
            &self.0
        }
    }
    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(&self.0);
        }
    }

    fn write(path: &Path, bytes: &[u8]) {
        let mut f = std::fs::File::create(path).unwrap();
        f.write_all(bytes).unwrap();
    }

    #[test]
    fn happy_path_patch_and_restore() {
        let td = TempDir::new();
        let target = td.path().join("a.txt");
        write(&target, b"original");

        let handle = apply(&target, |orig| {
            assert_eq!(orig, Some(&b"original"[..]));
            Ok(b"patched".to_vec())
        })
        .unwrap();

        assert_eq!(std::fs::read(&target).unwrap(), b"patched");
        drop(handle);
        assert_eq!(std::fs::read(&target).unwrap(), b"original");
    }

    #[test]
    fn no_original_sentinel() {
        let td = TempDir::new();
        let target = td.path().join("missing.txt");
        assert!(!target.exists());

        let handle = apply(&target, |orig| {
            assert!(orig.is_none());
            Ok(b"created".to_vec())
        })
        .unwrap();

        assert_eq!(std::fs::read(&target).unwrap(), b"created");
        drop(handle);
        assert!(!target.exists());
    }

    #[test]
    fn manual_restore_is_idempotent() {
        let td = TempDir::new();
        let target = td.path().join("b.txt");
        write(&target, b"orig");

        let handle = apply(&target, |_| Ok(b"patched".to_vec())).unwrap();
        handle.restore();
        handle.restore(); // second call: no panic, no effect
        assert_eq!(std::fs::read(&target).unwrap(), b"orig");
    }

    #[test]
    fn concurrent_claim_last_writer_wins() {
        let td = TempDir::new();
        let target = td.path().join("c.txt");
        write(&target, b"orig");

        let h1 = apply(&target, |orig| {
            assert_eq!(orig, Some(&b"orig"[..]));
            Ok(b"p1".to_vec())
        })
        .unwrap();

        assert_eq!(std::fs::read(&target).unwrap(), b"p1");

        // Second caller claims the lock h1 created. They should see the
        // original ("orig"), not h1's patched content.
        let h2 = apply(&target, |orig| {
            assert_eq!(orig, Some(&b"orig"[..]));
            Ok(b"p2".to_vec())
        })
        .unwrap();

        assert_eq!(std::fs::read(&target).unwrap(), b"p2");

        // Dropping h1 should no-op because its lock was claimed by h2.
        drop(h1);
        assert_eq!(std::fs::read(&target).unwrap(), b"p2");

        // Dropping h2 restores the original.
        drop(h2);
        assert_eq!(std::fs::read(&target).unwrap(), b"orig");
    }

    #[test]
    fn sweep_reverts_stale_but_keeps_live() {
        let td = TempDir::new();

        // Leaked patch where the original existed: sweep with a dead owner
        // renames the lock back over the target.
        let a = td.path().join("a.txt");
        write(&a, b"orig");
        std::mem::forget(apply(&a, |_| Ok(b"leaked".to_vec())).unwrap());
        assert_eq!(std::fs::read(&a).unwrap(), b"leaked");
        assert_eq!(sweep_stale(&a, |_| false).unwrap(), 1); // owner "dead"
        assert_eq!(std::fs::read(&a).unwrap(), b"orig");

        // Leaked patch where NO original existed: sweep deletes the target.
        let b = td.path().join("b.txt");
        std::mem::forget(apply(&b, |_| Ok(b"leaked".to_vec())).unwrap());
        assert!(b.exists());
        assert_eq!(sweep_stale(&b, |_| false).unwrap(), 1);
        assert!(!b.exists());

        // A live owner is left untouched.
        let c = td.path().join("c.txt");
        write(&c, b"orig");
        std::mem::forget(apply(&c, |_| Ok(b"active".to_vec())).unwrap());
        assert_eq!(sweep_stale(&c, |_| true).unwrap(), 0); // owner "alive"
        assert_eq!(std::fs::read(&c).unwrap(), b"active");
    }

    #[test]
    fn crash_recovery_via_claim() {
        let td = TempDir::new();
        let target = td.path().join("d.txt");
        write(&target, b"orig");

        // Simulate crash: apply, then forget the handle so Drop never runs.
        let h = apply(&target, |_| Ok(b"crashed-patched".to_vec())).unwrap();
        std::mem::forget(h);

        // Target is still patched; a stale lock exists.
        assert_eq!(std::fs::read(&target).unwrap(), b"crashed-patched");

        // New caller arrives. It should claim the stale lock and see the
        // ORIGINAL content (not the crashed patch).
        let h2 = apply(&target, |orig| {
            assert_eq!(orig, Some(&b"orig"[..]));
            Ok(b"recovered".to_vec())
        })
        .unwrap();
        assert_eq!(std::fs::read(&target).unwrap(), b"recovered");

        drop(h2);
        assert_eq!(std::fs::read(&target).unwrap(), b"orig");
    }
}
