use crate::util::config;
use clap::builder::styling::{AnsiColor, Effects, Styles};
use clap::{Parser, Subcommand};

const STYLES: Styles = Styles::styled()
    .header(AnsiColor::Yellow.on_default().effects(Effects::BOLD))
    .usage(AnsiColor::Yellow.on_default().effects(Effects::BOLD))
    .literal(AnsiColor::Red.on_default().effects(Effects::BOLD))
    .placeholder(AnsiColor::Yellow.on_default());

#[derive(Parser)]
#[command(name = "rodeo", about = "Command-line interface for Roblox Studio")]
#[command(version, styles = STYLES)]
pub struct Cli {
    /// Enable debug output
    #[arg(short, long, global = true)]
    pub verbose: bool,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Start persistent server (no Studio launch — use `run --place` for that)
    Serve {
        /// Port number for server
        #[arg(long)]
        port: Option<u16>,

        /// Run as master only (central orchestrator)
        #[arg(long, conflicts_with = "studio_mode")]
        master: bool,

        /// Run as studio backend only (connects to master)
        #[arg(long = "studio", conflicts_with = "master")]
        studio_mode: bool,

        /// Master host to connect to (for --studio)
        #[arg(long = "master-host", default_value = "localhost")]
        master_host: String,

        /// Master port to connect to (for --studio)
        #[arg(long = "master-port")]
        master_port: Option<u16>,

        /// Parent PID — exit when this process dies
        #[arg(long)]
        ppid: Option<u32>,
    },

    /// Run a script in Studio
    Run {
        /// Path to the script to execute, or '-' for stdin
        script: Option<String>,

        /// Execute source code passed as string
        #[arg(short, long)]
        source: Option<String>,

        /// Path to sourcemap.json for instance resolution
        #[arg(long)]
        sourcemap: Option<String>,

        /// Path to file for execution output (prints/logs)
        #[arg(long)]
        output: Option<String>,

        /// Path to file for return value JSON
        #[arg(long = "return")]
        return_file: Option<String>,

        /// Print return value to stdout
        #[arg(long)]
        show_return: bool,

        /// Target: mode:dom[:identity] (e.g. edit:plugin, test:server, play:client:plugin)
        #[arg(long)]
        target: Option<String>,

        /// Studio instance to target (StudioMCP ID or "active")
        #[arg(long)]
        studio: Option<String>,

        /// Disable warning output
        #[arg(long)]
        no_warn: bool,

        /// Disable error output
        #[arg(long)]
        no_error: bool,

        /// Disable info output
        #[arg(long)]
        no_info: bool,

        /// Disable print statements
        #[arg(long)]
        no_print: bool,

        /// Disable all output
        #[arg(long)]
        no_output: bool,

        /// Enable module caching (skip reloader for better performance)
        #[arg(long)]
        cache_requires: bool,

        /// Script arguments (passed after --)
        #[arg(last = true)]
        script_args: Vec<String>,

        /// Parent PID — exit when this process dies
        #[arg(long)]
        ppid: Option<u32>,

        #[command(flatten)]
        server: ServerArgs,

        #[command(flatten)]
        place: PlaceArgs,

        #[command(flatten)]
        fflags: FflagArgs,
    },

    /// List active processes
    Ps {
        #[command(flatten)]
        server: ServerArgs,
    },

    /// Kill a running process
    Kill {
        /// Process ID to kill
        id: u32,

        #[command(flatten)]
        server: ServerArgs,
    },

    /// Save the Studio place
    Save {
        /// Copy saved file to this output path
        #[arg(long)]
        out: Option<String>,

        #[command(flatten)]
        server: ServerArgs,
    },

    /// Build and install the rodeo plugin
    Plugin,

    /// Generate type definitions and configure .luaurc
    Setup,

    /// Start MCP server for AI agent integration
    Mcp {
        #[command(flatten)]
        server: ServerArgs,
    },

    /// Internal: studio daemon process (auto-started by studio backends)
    #[command(name = "__studio-daemon", hide = true)]
    StudioDaemon,

    /// Internal: master server process
    #[command(name = "__master", hide = true)]
    InternalMaster {
        #[arg(long)]
        port: u16,
        /// Parent PID — exit when this process dies
        #[arg(long)]
        ppid: Option<u32>,
    },

    /// Internal: studio backend process
    #[command(name = "__studio-backend", hide = true)]
    InternalStudioBackend {
        /// Local port for plugin WebSocket connections
        #[arg(long)]
        port: u16,
        /// Master host to connect to
        #[arg(long)]
        master_host: String,
        /// Master port to connect to
        #[arg(long)]
        master_port: u16,
        /// Parent PID — exit when this process dies
        #[arg(long)]
        ppid: Option<u32>,
    },

    /// Internal: process source (bundle + shim + resolve)
    #[command(name = "__process_source", hide = true)]
    ProcessSource {
        /// Script file to process
        script: Option<String>,
        /// Inline source to process
        #[arg(long)]
        source: Option<String>,
        /// Path to rojo sourcemap.json
        #[arg(long)]
        sourcemap: Option<String>,
    },

    /// Internal: canonical JSON-RPC 2.0 client over NDJSON on stdin/stdout.
    /// Spawned by language wrappers (rodeo-client-ts, rodeo-client-luau).
    #[command(name = "__spawn_canonical_client", hide = true)]
    SpawnCanonicalClient {
        /// Master host
        #[arg(long, default_value = "localhost")]
        host: String,
        /// Master port
        #[arg(long)]
        port: u16,
    },
}

/// Shared args for connecting to a running rodeo server
#[derive(clap::Args, Clone)]
pub struct ServerArgs {
    /// Host of running server
    #[arg(long, default_value = "localhost")]
    pub host: String,

    /// Port number of running server
    #[arg(long, default_value_t = config::SERVE_PORT)]
    pub port: u16,
}

/// Shared args for launching Studio/Player and targeting VMs
#[derive(clap::Args, Clone, Default)]
pub struct PlaceArgs {
    /// Launch Studio: empty (no value), place ID (number), or file path (.rbxl/.rbxlx)
    #[arg(long = "place", num_args = 0..=1, default_missing_value = "", help_heading = "Launch")]
    pub place: Option<String>,

    /// Target a specific server instance by job ID (gameInstanceId)
    #[arg(long, help_heading = "Targeting")]
    pub job: Option<String>,

    /// Target a specific VM directly by ID
    #[arg(long, help_heading = "Targeting")]
    pub vm: Option<String>,

    /// Target a specific backend device (by name or ID)
    #[arg(long, help_heading = "Targeting")]
    pub backend: Option<String>,

    /// Universe ID (resolved from place ID if omitted)
    #[arg(long = "place.universe", value_name = "UNIVERSE_ID", help_heading = "Launch")]
    pub place_universe: Option<u64>,

    /// Bring Studio to the foreground on launch (default: background)
    #[arg(long)]
    pub focus: bool,

    /// Keep Studio/Player running after rodeo exits
    #[arg(long = "detached", help_heading = "Launch")]
    pub detached: bool,

    /// Strip Studio UI panels (Explorer/Properties/Toolbox/Output/etc.) for a
    /// minimal launch. Applies only to the Studio rodeo launches; restored on exit.
    #[arg(long = "no-hud", help_heading = "Launch")]
    pub no_hud: bool,

    /// Enable microprofiler auto-capture and collect dumps (optional: output directory)
    #[arg(long = "profile", num_args = 0..=1, default_missing_value = "", help_heading = "Profiling")]
    pub profile: Option<String>,

    /// Collect Studio log output for this run (optional: output directory)
    #[arg(long = "logs", num_args = 0..=1, default_missing_value = "", help_heading = "Profiling")]
    pub logs: Option<String>,

    /// Save Studio place on exit, optionally to a specific path
    #[arg(long, num_args = 0..=1, default_missing_value = "")]
    pub save: Option<String>,
}

impl PlaceArgs {
    /// Convert to PlaceTarget. Returns None if no launch requested.
    pub fn to_target(&self) -> Option<crate::studio_backend::PlaceTarget> {
        let val = self.place.as_deref()?;
        if val.is_empty() {
            Some(crate::studio_backend::PlaceTarget::Empty)
        } else if let Ok(pid) = val.parse::<u64>() {
            Some(crate::studio_backend::PlaceTarget::PlaceId {
                place_id: pid,
                universe_id: self.place_universe,
            })
        } else {
            Some(crate::studio_backend::PlaceTarget::File(val.to_string()))
        }
    }
}

/// Shared args for FFlag configuration
#[derive(clap::Args, Clone, Default)]
pub struct FflagArgs {
    /// Set FFlag override (Key=Value, repeatable)
    #[arg(long = "fflag.override", value_name = "KEY=VALUE", help_heading = "FFlags")]
    pub fflag_override: Vec<String>,

    /// Load FFlag overrides from a JSON file
    #[arg(long = "fflag.file", value_name = "PATH", help_heading = "FFlags")]
    pub fflag_file: Option<String>,
}
