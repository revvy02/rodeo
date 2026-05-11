use anyhow::{Context, Result};
use rbx_dom_weak::types::Variant;

/// Embedded plugin binary (pre-built .rbxm)
const PLUGIN_BINARY: &[u8] = include_bytes!("../../../rodeo-plugin/build/plugin.rbxm");

/// Configuration for a launched plugin instance
pub struct PluginConfig {
    pub port: u16,
    pub host: String,
    pub auto_connect: bool,
    pub settings_panel_enabled: bool,
    pub match_place_id: Option<u64>,
    pub match_universe_id: Option<u64>,
    /// Master-minted session identity baked into the plugin's `flags.SESSION_GUID`.
    /// Plugin includes it on the WS handshake so master stamps the connecting VM's
    /// `session_guid` synchronously (replacing the previous `TOKEN` field).
    pub session_guid: Option<String>,
    /// When true, plugin gates activation on `Workspace:GetAttribute("__RODEO_SESSION_GUID__")`
    /// matching `flags.SESSION_GUID`. Only possible for local-file launches
    /// (where rodeo stamped the attribute).
    pub check_workspace_session_guid_attr_matches: bool,
}

/// Write the embedded plugin to the Studio plugins directory (unpatched)
pub fn write_embedded_plugin(target_path: &str) -> Result<()> {
    std::fs::write(target_path, PLUGIN_BINARY)
        .context("failed to write plugin")
}

/// Write a patched plugin with launch-specific config to the target path.
///
/// Deserializes the embedded .rbxm, finds the `flags` ModuleScript,
/// rewrites its Source with the given config, and re-serializes.
pub fn write_patched_plugin(target_path: &str, config: &PluginConfig) -> Result<()> {
    let mut dom = rbx_binary::from_reader(std::io::Cursor::new(PLUGIN_BINARY))
        .context("failed to parse embedded plugin")?;

    let version = env!("CARGO_PKG_VERSION");
    let new_source = generate_flags_source(config, version);

    // Find the "flags" ModuleScript by walking the DOM
    let flags_ref = find_instance_by_name(&dom, "flags")
        .context("could not find 'flags' ModuleScript in plugin")?;

    let flags_inst = dom.get_by_ref_mut(flags_ref)
        .context("invalid flags instance ref")?;
    flags_inst.properties.insert(
        "Source".into(),
        Variant::String(new_source),
    );

    // Re-serialize
    let root = dom.root();
    let refs = root.children();
    let mut buf = Vec::new();
    rbx_binary::to_writer(&mut buf, &dom, refs)
        .context("failed to serialize patched plugin")?;

    std::fs::write(target_path, buf)
        .context("failed to write patched plugin")
}

/// Generate the Luau source for flags.luau with the given config.
fn generate_flags_source(config: &PluginConfig, version: &str) -> String {
    let match_section = match (config.match_place_id, config.match_universe_id) {
        (Some(place_id), Some(universe_id)) => {
            format!("{{ placeId = {place_id}, gameId = {universe_id} }}")
        }
        (Some(place_id), None) => {
            format!("{{ placeId = {place_id}, gameId = 0 }}")
        }
        _ => "nil".to_string(),
    };

    let session_guid_section = match &config.session_guid {
        Some(t) => format!("\"{t}\""),
        None => "nil".to_string(),
    };

    format!(
        r#"return {{
	VERSION = "{version}",
	VERBOSE = false,
	SETTINGS_PANEL_ENABLED = {settings_panel},
	SETTINGS = {{
		host = "{host}",
		port = {port},
		autoConnect = {auto_connect},
	}},
	MATCH = {match_section},
	SESSION_GUID = {session_guid_section},
	CHECK_WORKSPACE_SESSION_GUID_ATTR_MATCHES = {check_attr},
}}"#,
        version = version,
        settings_panel = if config.settings_panel_enabled { "true" } else { "false" },
        host = config.host,
        port = config.port,
        auto_connect = if config.auto_connect { "true" } else { "false" },
        match_section = match_section,
        session_guid_section = session_guid_section,
        check_attr = if config.check_workspace_session_guid_attr_matches { "true" } else { "false" },
    )
}

/// Recursively find an instance by name in the DOM.
fn find_instance_by_name(
    dom: &rbx_dom_weak::WeakDom,
    name: &str,
) -> Option<rbx_dom_weak::types::Ref> {
    let root = dom.root_ref();
    find_recursive(dom, root, name)
}

fn find_recursive(
    dom: &rbx_dom_weak::WeakDom,
    parent: rbx_dom_weak::types::Ref,
    name: &str,
) -> Option<rbx_dom_weak::types::Ref> {
    let inst = dom.get_by_ref(parent)?;
    for &child_ref in inst.children() {
        if let Some(child) = dom.get_by_ref(child_ref) {
            if child.name == name {
                return Some(child_ref);
            }
            if let Some(found) = find_recursive(dom, child_ref, name) {
                return Some(found);
            }
        }
    }
    None
}

