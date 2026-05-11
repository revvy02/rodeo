//! Client for the Studio launch-slot daemon. Used by Studio launch sites to
//! acquire/release slots. Auto-starts the daemon if not running.

use anyhow::{bail, Context, Result};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::process::{Command, Stdio};
use std::time::Duration;

use super::{DaemonPaths, Request, Response};

/// Handle to an acquired launch slot. Sends `release_slot` on drop.
pub struct SlotHandle {
    slot_id: String,
    stream: Option<UnixStream>,
    next_id: u64,
}

impl SlotHandle {
    /// Notify daemon that Studio has launched and login is complete.
    pub fn launch_complete(&mut self, pid: u32) -> Result<()> {
        let stream = self.stream.as_mut().context("daemon connection lost")?;
        let req = Request::LaunchComplete {
            id: self.next_id,
            slot_id: self.slot_id.clone(),
            pid,
        };
        self.next_id += 1;
        send(stream, &req)?;
        let _resp = recv(stream)?;
        Ok(())
    }

}

impl Drop for SlotHandle {
    fn drop(&mut self) {
        tracing::info!(slot_id = %self.slot_id, "daemon: SlotHandle::Drop — sending ReleaseSlot");
        if let Some(ref mut stream) = self.stream {
            let req = Request::ReleaseSlot {
                id: self.next_id,
                slot_id: self.slot_id.clone(),
            };
            let _ = send(stream, &req);
        }
    }
}

/// Connect to the daemon (auto-starting if needed) and acquire a launch slot.
///
/// Blocks until a slot is available and the login gate is clear. Returns a
/// SlotHandle that releases the slot on drop.
///
/// `subcommand` is the CLI argument the caller binary accepts to dispatch
/// into [`super::main`] — e.g. `"__studio-daemon"`. The current executable
/// is re-invoked with that single arg to start the daemon process.
pub fn acquire_slot(paths: &DaemonPaths, subcommand: &str) -> Result<SlotHandle> {
    tracing::info!("daemon: connecting");
    let mut stream = connect_or_spawn(paths, subcommand)?;
    tracing::info!("daemon: connected, sending AcquireSlot");

    // Send acquire request
    let req = Request::AcquireSlot { id: 1 };
    send(&mut stream, &req)?;
    tracing::info!("daemon: AcquireSlot sent, waiting for response (this blocks until daemon grants)");

    // Block waiting for response (daemon sends it when slot is granted)
    let resp = recv(&mut stream)?;
    tracing::info!("daemon: granted slot");

    let slot_id = resp
        .result
        .as_ref()
        .and_then(|r| r.get("slot_id"))
        .and_then(|v| v.as_str())
        .context("daemon response missing slot_id")?
        .to_string();

    Ok(SlotHandle {
        slot_id,
        stream: Some(stream),
        next_id: 2,
    })
}

/// Try to connect to existing daemon, or spawn one.
/// Uses a file lock to prevent multiple processes from spawning daemons simultaneously.
fn connect_or_spawn(paths: &DaemonPaths, subcommand: &str) -> Result<UnixStream> {
    let sock = paths.socket();

    // Fast path: try existing daemon
    if let Ok(stream) = UnixStream::connect(&sock) {
        return Ok(stream);
    }

    // Acquire spawn lock to prevent multiple daemons
    let daemon_dir = paths.dir();
    std::fs::create_dir_all(daemon_dir).ok();
    let lock_path = paths.lock();
    let lock_file = std::fs::OpenOptions::new()
        .create(true)
        .write(true)
        .open(&lock_path)
        .context("failed to open daemon spawn lock")?;

    use std::os::unix::io::AsRawFd;
    let fd = lock_file.as_raw_fd();
    unsafe { libc::flock(fd, libc::LOCK_EX); }

    // Re-check after acquiring lock — another process may have started the daemon
    if let Ok(stream) = UnixStream::connect(&sock) {
        unsafe { libc::flock(fd, libc::LOCK_UN); }
        return Ok(stream);
    }

    // We're the one to spawn
    let exe = std::env::current_exe().context("cannot find own binary")?;
    let log_file = std::fs::OpenOptions::new()
        .create(true)
        .append(true)
        .open(paths.log())
        .context("failed to create daemon log")?;
    tracing::debug!("spawning studio daemon: {:?}", exe);
    #[cfg(unix)]
    {
        use std::os::unix::process::CommandExt;
        unsafe {
            Command::new(&exe)
                .arg(subcommand)
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::from(log_file))
                .pre_exec(|| { libc::setsid(); Ok(()) })
                .spawn()
                .context("failed to spawn studio daemon")?;
        }
    }
    #[cfg(not(unix))]
    {
        Command::new(&exe)
            .arg(subcommand)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::from(log_file))
            .spawn()
            .context("failed to spawn studio daemon")?;
    }

    // Poll until socket appears
    for _ in 0..60 {
        std::thread::sleep(Duration::from_millis(100));
        if let Ok(stream) = UnixStream::connect(&sock) {
            unsafe { libc::flock(fd, libc::LOCK_UN); }
            return Ok(stream);
        }
    }

    unsafe { libc::flock(fd, libc::LOCK_UN); }
    bail!("studio daemon did not start within 6s")
}

fn send(stream: &mut UnixStream, request: &Request) -> Result<()> {
    let mut msg = serde_json::to_string(request)?;
    msg.push('\n');
    stream.write_all(msg.as_bytes())?;
    stream.flush()?;
    Ok(())
}

fn recv(stream: &mut UnixStream) -> Result<Response> {
    let mut reader = BufReader::new(stream);
    let mut line = String::new();
    reader.read_line(&mut line)?;
    let resp: Response = serde_json::from_str(&line)?;
    if let Some(ref err) = resp.error {
        bail!("daemon error: {err}");
    }
    Ok(resp)
}
