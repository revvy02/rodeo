use anyhow::{Context, Result};
use crate::studio_backend::plugin_embed;

pub fn main() -> Result<()> {
    let studio = roblox_install::RobloxStudio::locate()
        .context("failed to locate Roblox Studio install")?;
    let plugin_dir = studio.plugins_path();

    std::fs::create_dir_all(plugin_dir)
        .context("failed to create plugins directory")?;

    let target_path = plugin_dir.join("rodeo.rbxm");
    let target_path_str = target_path.to_string_lossy();
    plugin_embed::write_embedded_plugin(&target_path_str)?;

    tracing::info!("Plugin installed to {}", target_path.display());
    tracing::info!("Restart Roblox Studio to activate the plugin");

    Ok(())
}
