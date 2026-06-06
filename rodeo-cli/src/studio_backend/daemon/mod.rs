//! Studio launch slot supervisor.
//!
//! Runs as a hidden subprocess that gates concurrent Studio launches via a
//! local socket (a Unix-domain socket on macOS/Linux, a named pipe on
//! Windows — see `daemon_socket_name`). Callers acquire a slot before
//! spawning Studio, hold it
//! through the login handshake, then release when Studio exits.
//!
//! Two invariants the daemon enforces:
//! - Max concurrent Studios (configured by the caller via `DaemonRunOpts`).
//! - Serialized login handshake: only one Studio launches at a time, which
//!   avoids the Roblox auth-token race seen under parallel launches.
//!
//! The daemon does not launch Studio itself; it's pure admission control.
//! The filesystem layout (socket/pid/log/lock paths) is supplied by the
//! caller via `DaemonPaths` — nothing here hardcodes a directory or env var.

use anyhow::{Context, Result};
use interprocess::local_socket::Name;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub mod client;
pub mod server;

pub use client::{acquire_slot, SlotHandle};
pub use server::main;

/// Build the interprocess local-socket name for this daemon instance.
///
/// On Unix this is the filesystem path of the `.sock` file, preserving the
/// existing socket-file semantics (stale-file cleanup, existence checks). On
/// Windows std exposes no AF_UNIX, so we use a named pipe whose name is
/// derived (hashed) from the daemon directory — stable per directory so
/// distinct rodeo workspaces get distinct daemons rather than colliding.
#[cfg(unix)]
pub(crate) fn daemon_socket_name(paths: &DaemonPaths) -> Result<Name<'static>> {
    use interprocess::local_socket::{GenericFilePath, ToFsName};
    paths
        .socket()
        .into_os_string()
        .to_fs_name::<GenericFilePath>()
        .context("invalid daemon socket path")
}

#[cfg(windows)]
pub(crate) fn daemon_socket_name(paths: &DaemonPaths) -> Result<Name<'static>> {
    use interprocess::local_socket::{GenericNamespaced, ToNsName};
    // FNV-1a over the directory path bytes. A *stable* hash matters here:
    // std's DefaultHasher is explicitly not guaranteed stable across compiler
    // versions, so a rebuilt CLI could compute a different pipe name, miss a
    // still-running daemon, and spawn a duplicate. FNV-1a is fixed forever.
    let mut hash: u64 = 0xcbf2_9ce4_8422_2325;
    for byte in paths.dir().to_string_lossy().as_bytes() {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(0x0000_0100_0000_01b3);
    }
    let name = format!("rodeo-studio-daemon-{hash:016x}");
    name.to_ns_name::<GenericNamespaced>()
        .context("invalid daemon pipe name")
}

/// Filesystem layout for a daemon instance.
///
/// The caller owns the directory; this struct derives the daemon's file
/// names from it. Filenames are stable (`studio-daemon.sock`, etc.) — only
/// the containing directory is configurable.
#[derive(Clone, Debug)]
pub struct DaemonPaths {
    dir: PathBuf,
}

impl DaemonPaths {
    /// Create paths rooted at `dir`. Caller ensures the directory exists
    /// or will create it (`socket`/`pid` creation will `mkdir -p` if needed).
    pub fn new(dir: impl Into<PathBuf>) -> Self {
        Self { dir: dir.into() }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    pub fn socket(&self) -> PathBuf {
        self.dir.join("studio-daemon.sock")
    }

    pub fn pid(&self) -> PathBuf {
        self.dir.join("studio-daemon.pid")
    }

    pub fn lock(&self) -> PathBuf {
        self.dir.join("daemon-spawn.lock")
    }

    pub fn log(&self) -> PathBuf {
        self.dir.join("studio-daemon.log")
    }
}

/// Runtime options for the daemon server loop.
#[derive(Clone, Debug)]
pub struct DaemonRunOpts {
    pub paths: DaemonPaths,
    /// Maximum concurrent Studio instances the daemon will permit.
    pub max_slots: usize,
    /// When true, gate the login handshake so only one Studio is mid-launch
    /// at a time. Avoids the auth-token race; safe to leave on unless a
    /// consumer has verified the race doesn't affect them.
    pub serialize_launches: bool,
}

// ---------------------------------------------------------------------------
// Protocol — newline-delimited JSON over the local socket
// ---------------------------------------------------------------------------

#[derive(Debug, Serialize, Deserialize)]
#[serde(tag = "method", rename_all = "snake_case")]
pub enum Request {
    /// Request permission to launch a Studio. Blocks until granted.
    AcquireSlot { id: u64 },
    /// Studio has launched and completed login. Unblocks the next queued launch.
    LaunchComplete { id: u64, slot_id: String, pid: u32 },
    /// Release a slot (Studio exiting). Frees capacity for queued requests.
    ReleaseSlot { id: u64, slot_id: String },
    /// Query daemon status.
    Status { id: u64 },
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Response {
    pub id: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<serde_json::Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}
