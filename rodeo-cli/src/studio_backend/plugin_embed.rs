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
///
/// Idempotent: skips the write when the installed file already matches the
/// embedded bytes. Studio reloads a plugin whenever its file changes on disk —
/// even a same-bytes rewrite bumps the mtime and triggers a reload — so an
/// unconditional write would reload the plugin on every launch. Writing only on
/// a real change still self-heals after `lune run build` updates the bytes.
pub fn write_embedded_plugin(target_path: &str) -> Result<()> {
    if std::fs::read(target_path).ok().as_deref() == Some(PLUGIN_BINARY) {
        return Ok(());
    }
    std::fs::write(target_path, PLUGIN_BINARY).context("failed to write plugin")
}
