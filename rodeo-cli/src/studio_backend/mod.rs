pub mod backend;
pub mod connection;
pub mod daemon;
pub mod http;
pub mod plugin_embed;
pub mod plugin_lock;
pub mod plugin_ws;
pub mod launch;

pub use launch::*;

/// Subcommand name the current rodeo binary uses to dispatch into the
/// studio-daemon server loop.
pub const DAEMON_SUBCOMMAND: &str = "__studio-daemon";

/// Filesystem layout for the daemon (`~/.rodeo/`). Shared by the daemon
/// server loop (in main.rs dispatch) and the client (studio_backend::launch).
pub fn daemon_paths() -> daemon::DaemonPaths {
    let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
    daemon::DaemonPaths::new(home.join(".rodeo"))
}

/// Resolve daemon runtime options from rodeo env vars (RODEO_MAX_STUDIOS,
/// RODEO_SERIALIZE_LAUNCHES). Called by main.rs when dispatching
/// `__studio-daemon`.
pub fn daemon_run_opts() -> daemon::DaemonRunOpts {
    let max_slots = std::env::var("RODEO_MAX_STUDIOS")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(4);
    let serialize_launches = std::env::var("RODEO_SERIALIZE_LAUNCHES")
        .map(|v| v != "0" && v != "false")
        .unwrap_or(true);
    daemon::DaemonRunOpts {
        paths: daemon_paths(),
        max_slots,
        serialize_launches,
    }
}
