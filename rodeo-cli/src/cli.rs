use crate::util::config;

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
