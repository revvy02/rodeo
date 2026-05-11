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

/// Build the lock filename `<basename>.lock.<uuid>` next to `path`.
fn lock_path_for(path: &Path, uuid: &str) -> PathBuf {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let base = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
    dir.join(format!("{base}{LOCK_INFIX}{uuid}"))
}

/// Find any existing `<basename>.lock.*` file in the same directory as `path`.
///
/// Used to detect a prior patch (either an active one from another process or
/// a stale one from a crashed process) so we can claim it via rename.
fn find_existing_lock(path: &Path) -> Option<PathBuf> {
    let dir = path.parent().unwrap_or_else(|| Path::new("."));
    let base = path.file_name().and_then(|n| n.to_str())?;
    let prefix = format!("{base}{LOCK_INFIX}");
    for entry in std::fs::read_dir(dir).ok()?.flatten() {
        if entry
            .file_name()
            .to_str()
            .map_or(false, |n| n.starts_with(&prefix))
        {
            return Some(entry.path());
        }
    }
    None
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
    let lock_path = lock_path_for(path, &owner_uuid);

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
