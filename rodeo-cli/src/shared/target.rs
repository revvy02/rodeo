use anyhow::{bail, Result};

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ScriptIdentity {
    Plugin,
    Server,
    Client,
    Elevated,
}

impl ScriptIdentity {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Plugin => "plugin",
            Self::Server => "server",
            Self::Client => "client",
            Self::Elevated => "elevated",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StudioMode {
    Edit,
    Run,
    Test,
    Play,
}

impl StudioMode {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Edit => "edit",
            Self::Run => "run",
            Self::Test => "test",
            Self::Play => "play",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Dom {
    Edit,
    Server,
    Client,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Target {
    pub mode: StudioMode,
    pub dom: Dom,
    pub identity: ScriptIdentity,
    /// For play:client — the client index (1-based). None = append (spawn new client).
    pub client_index: Option<u32>,
}


impl std::fmt::Display for Target {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // play:client has dynamic index — format it specially
        if self.mode == StudioMode::Play && self.dom == Dom::Client {
            write!(f, "play:client")?;
            if let Some(idx) = self.client_index {
                write!(f, ":{idx}")?;
            }
            if self.identity != ScriptIdentity::Client {
                write!(f, ":{}", self.identity.as_str())?;
            }
            return Ok(());
        }
        write!(f, "{}", to_str(self))
    }
}

fn to_str(t: &Target) -> &'static str {
    match (t.mode, t.dom, t.identity) {
        (StudioMode::Edit, Dom::Edit, ScriptIdentity::Plugin) => "edit:plugin",
        (StudioMode::Edit, Dom::Edit, ScriptIdentity::Elevated) => "edit:elevated",

        (StudioMode::Run, Dom::Server, ScriptIdentity::Server) => "run:server",
        (StudioMode::Run, Dom::Server, ScriptIdentity::Plugin) => "run:server:plugin",
        (StudioMode::Run, Dom::Server, ScriptIdentity::Elevated) => "run:server:elevated",

        (StudioMode::Test, Dom::Server, ScriptIdentity::Server) => "test:server",
        (StudioMode::Test, Dom::Server, ScriptIdentity::Plugin) => "test:server:plugin",
        (StudioMode::Test, Dom::Server, ScriptIdentity::Elevated) => "test:server:elevated",
        (StudioMode::Test, Dom::Client, ScriptIdentity::Client) => "test:client",
        (StudioMode::Test, Dom::Client, ScriptIdentity::Plugin) => "test:client:plugin",
        (StudioMode::Test, Dom::Client, ScriptIdentity::Elevated) => "test:client:elevated",

        (StudioMode::Play, Dom::Server, ScriptIdentity::Server) => "play:server",
        (StudioMode::Play, Dom::Server, ScriptIdentity::Plugin) => "play:server:plugin",
        (StudioMode::Play, Dom::Server, ScriptIdentity::Elevated) => "play:server:elevated",
        // play:client handled by Display impl (dynamic index)
        (StudioMode::Play, Dom::Client, _) => "play:client",

        _ => "unknown",
    }
}

pub fn parse(s: &str) -> Result<Target> {
    // Try play:client with optional index first (special 3-4 segment format)
    if let Some(rest) = s.strip_prefix("play:client") {
        return parse_play_client(rest);
    }

    let t = match s {
        "edit:plugin" => Target { mode: StudioMode::Edit, dom: Dom::Edit, identity: ScriptIdentity::Plugin, client_index: None },
        "edit:elevated" => Target { mode: StudioMode::Edit, dom: Dom::Edit, identity: ScriptIdentity::Elevated, client_index: None },

        "run:server" => Target { mode: StudioMode::Run, dom: Dom::Server, identity: ScriptIdentity::Server, client_index: None },
        "run:server:plugin" => Target { mode: StudioMode::Run, dom: Dom::Server, identity: ScriptIdentity::Plugin, client_index: None },
        "run:server:elevated" => Target { mode: StudioMode::Run, dom: Dom::Server, identity: ScriptIdentity::Elevated, client_index: None },

        "test:server" => Target { mode: StudioMode::Test, dom: Dom::Server, identity: ScriptIdentity::Server, client_index: None },
        "test:server:plugin" => Target { mode: StudioMode::Test, dom: Dom::Server, identity: ScriptIdentity::Plugin, client_index: None },
        "test:server:elevated" => Target { mode: StudioMode::Test, dom: Dom::Server, identity: ScriptIdentity::Elevated, client_index: None },
        "test:client" => Target { mode: StudioMode::Test, dom: Dom::Client, identity: ScriptIdentity::Client, client_index: None },
        "test:client:plugin" => Target { mode: StudioMode::Test, dom: Dom::Client, identity: ScriptIdentity::Plugin, client_index: None },
        "test:client:elevated" => Target { mode: StudioMode::Test, dom: Dom::Client, identity: ScriptIdentity::Elevated, client_index: None },

        "play:server" => Target { mode: StudioMode::Play, dom: Dom::Server, identity: ScriptIdentity::Server, client_index: None },
        "play:server:plugin" => Target { mode: StudioMode::Play, dom: Dom::Server, identity: ScriptIdentity::Plugin, client_index: None },
        "play:server:elevated" => Target { mode: StudioMode::Play, dom: Dom::Server, identity: ScriptIdentity::Elevated, client_index: None },

        _ => bail!(
            "unknown target '{s}'\n\
             Valid targets:\n\
             edit:plugin, edit:elevated\n\
             run:server, run:server:plugin, run:server:elevated\n\
             test:server, test:server:plugin, test:server:elevated\n\
             test:client, test:client:plugin, test:client:elevated\n\
             play:server, play:server:plugin, play:server:elevated\n\
             play:client, play:client:N, play:client:N:identity"
        ),
    };
    Ok(t)
}

/// Parse `play:client` variants. `rest` is everything after "play:client".
///
/// Formats:
///   ""             → append mode (no index), client identity
///   ":plugin"      → append mode, plugin identity
///   ":elevated"    → append mode, elevated identity
///   ":1"           → target client #1, client identity
///   ":1:plugin"    → target client #1, plugin identity
///   ":1:elevated"  → target client #1, elevated identity
fn parse_play_client(rest: &str) -> Result<Target> {
    let base = Target {
        mode: StudioMode::Play,
        dom: Dom::Client,
        identity: ScriptIdentity::Client,
        client_index: None,
    };

    if rest.is_empty() {
        return Ok(base);
    }

    let parts: Vec<&str> = rest[1..].split(':').collect(); // skip leading ':'

    match parts.as_slice() {
        // play:client:plugin or play:client:elevated
        [ident] if parse_identity(ident).is_some() => {
            Ok(Target { identity: parse_identity(ident).unwrap(), ..base })
        }
        // play:client:N
        [n] => {
            let idx = n.parse::<u32>().map_err(|_| anyhow::anyhow!(
                "invalid play:client index '{n}' — expected a number or identity (plugin/elevated)"
            ))?;
            Ok(Target { client_index: Some(idx), ..base })
        }
        // play:client:N:identity
        [n, ident] => {
            let idx = n.parse::<u32>().map_err(|_| anyhow::anyhow!(
                "invalid play:client index '{n}' — expected a number"
            ))?;
            let identity = parse_identity(ident).ok_or_else(|| anyhow::anyhow!(
                "unknown identity '{ident}' — expected plugin, server, client, or elevated"
            ))?;
            Ok(Target { client_index: Some(idx), identity, ..base })
        }
        _ => bail!("invalid play:client target 'play:client{rest}'"),
    }
}

fn parse_identity(s: &str) -> Option<ScriptIdentity> {
    match s {
        "plugin" => Some(ScriptIdentity::Plugin),
        "server" => Some(ScriptIdentity::Server),
        "client" => Some(ScriptIdentity::Client),
        "elevated" => Some(ScriptIdentity::Elevated),
        _ => None,
    }
}

#[allow(dead_code)]
pub fn default() -> Target {
    Target {
        mode: StudioMode::Edit,
        dom: Dom::Edit,
        identity: ScriptIdentity::Plugin,
        client_index: None,
    }
}
