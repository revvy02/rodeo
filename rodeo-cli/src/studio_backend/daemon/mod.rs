//! Studio launch slot supervisor.
//!
//! Runs as a hidden subprocess that gates concurrent Studio launches via a
//! Unix socket. Callers acquire a slot before spawning Studio, hold it
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

use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub mod client;
pub mod server;

pub use client::{acquire_slot, SlotHandle};
pub use server::main;

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
// Protocol — newline-delimited JSON over Unix socket
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
