use anyhow::{Context, Result};

/// Embedded plugin binary (pre-built .rbxm).
///
/// The plugin is fully static — it carries no launch-specific config. A rodeo
/// launch routes it via the `rodeoPort`/`rodeoSession` Workspace attributes set
/// by the RunScript bootstrap; a manual Studio connects on the plugin's own
/// defaults. So the same bytes are written for both `rodeo plugin` (manual
/// install) and launch-managed installs.
const PLUGIN_BINARY: &[u8] = include_bytes!("../../../rodeo-plugin/build/plugin.rbxm");

/// Write the embedded plugin to a target path in the Studio plugins directory.
pub fn write_embedded_plugin(target_path: &str) -> Result<()> {
    std::fs::write(target_path, PLUGIN_BINARY).context("failed to write plugin")
}
