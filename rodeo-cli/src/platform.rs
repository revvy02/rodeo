//! Small cross-platform shims for OS operations that have no portable crate
//! equivalent. The rest of rodeo-cli's process/daemon layer funnels through
//! here, so call sites stay `#[cfg]`-free — the only platform branching lives
//! in this module.

use anyhow::{Context, Result};
use std::fs::File;
use std::path::Path;
use std::process::{Command, Stdio};

/// Terminate a process by PID.
///
/// `force` selects the non-catchable kill (SIGKILL) over a graceful request
/// (SIGTERM) on Unix. Windows has no graceful equivalent for an arbitrary
/// process, so both map to `taskkill /F`; the `/T` flag also reaps the
/// process tree, matching the Unix process-group kill semantics callers rely
/// on. Returns true if the kill was dispatched successfully.
#[cfg(unix)]
pub fn kill_process(pid: u32, force: bool) -> bool {
    let sig = if force { libc::SIGKILL } else { libc::SIGTERM };
    unsafe { libc::kill(pid as i32, sig) == 0 }
}

#[cfg(windows)]
pub fn kill_process(pid: u32, _force: bool) -> bool {
    use std::os::windows::process::CommandExt;
    // taskkill.exe is a console program; without CREATE_NO_WINDOW a console
    // window briefly flashes on every kill (e.g. tearing down Studio at the
    // end of a run).
    const CREATE_NO_WINDOW: u32 = 0x0800_0000;
    Command::new("taskkill")
        .args(["/PID", &pid.to_string(), "/T", "/F"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .creation_flags(CREATE_NO_WINDOW)
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Spawn `exe <arg>` as a detached background process whose lifetime is
/// independent of the spawning process, with stderr redirected to `log`.
///
/// Unix detaches via `setsid()` (new session, no controlling terminal).
/// Windows uses `DETACHED_PROCESS | CREATE_NO_WINDOW` so the daemon outlives
/// the CLI and never flashes a console window (`CREATE_NEW_PROCESS_GROUP`
/// keeps Ctrl+C from the parent console out of the daemon's group).
pub fn spawn_daemon_detached(exe: &Path, arg: &str, log: File) -> Result<()> {
    let mut cmd = Command::new(exe);
    cmd.arg(arg)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::from(log));

    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        unsafe {
            cmd.pre_exec(|| {
                libc::setsid();
                Ok(())
            });
        }
    }
    #[cfg(windows)]
    {
        use std::os::windows::process::CommandExt;
        const DETACHED_PROCESS: u32 = 0x0000_0008;
        const CREATE_NO_WINDOW: u32 = 0x0800_0000;
        const CREATE_NEW_PROCESS_GROUP: u32 = 0x0000_0200;
        cmd.creation_flags(DETACHED_PROCESS | CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP);
    }

    cmd.spawn().context("failed to spawn studio daemon")?;
    Ok(())
}

/// Remove a stale local-socket file left by a crashed daemon.
///
/// Unix-only: a Unix-domain socket is a filesystem entry that lingers after a
/// crash. Windows named pipes have no filesystem entry and are reclaimed when
/// the last handle closes, so this is a no-op there.
pub fn cleanup_stale_socket(path: &Path) {
    #[cfg(unix)]
    let _ = std::fs::remove_file(path);
    #[cfg(not(unix))]
    let _ = path;
}
