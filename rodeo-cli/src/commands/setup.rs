use anyhow::{Context, Result};
use std::path::PathBuf;

static TYPEDEF_INIT: &str = include_str!("../../../rodeo-pkg/src/init.luau");
static TYPEDEF_FS: &str = include_str!("../../../rodeo-pkg/src/fs.luau");
static TYPEDEF_IO: &str = include_str!("../../../rodeo-pkg/src/io.luau");
static TYPEDEF_PROCESS: &str = include_str!("../../../rodeo-pkg/src/process.luau");
static TYPEDEF_STREAM: &str = include_str!("../../../rodeo-pkg/src/stream.luau");
static TYPEDEF_ROBLOX: &str = include_str!("../../../rodeo-pkg/src/roblox.luau");

static TYPEDEFS: [(&str, &str); 6] = [
    ("init.luau", TYPEDEF_INIT),
    ("fs.luau", TYPEDEF_FS),
    ("io.luau", TYPEDEF_IO),
    ("process.luau", TYPEDEF_PROCESS),
    ("stream.luau", TYPEDEF_STREAM),
    ("roblox.luau", TYPEDEF_ROBLOX),
];

pub fn main() -> Result<()> {
    let version = env!("CARGO_PKG_VERSION");
    let home = PathBuf::from(std::env::var("HOME").context("HOME not set")?);

    // Write typedefs to ~/.rodeo/typedefs/{version}/
    let typedefs_dir = home.join(".rodeo").join("typedefs").join(version);
    if typedefs_dir.exists() {
        std::fs::remove_dir_all(&typedefs_dir)
            .context("failed to remove existing typedefs directory")?;
    }
    std::fs::create_dir_all(&typedefs_dir)
        .context("failed to create typedefs directory")?;

    for (filename, content) in &TYPEDEFS {
        let path = typedefs_dir.join(filename);
        std::fs::write(&path, content)
            .context(format!("failed to write {filename}"))?;
    }

    let pretty_path = format!("~/.rodeo/typedefs/{version}");
    tracing::info!("Wrote type definitions to {pretty_path}");

    // Update .rodeo/.luaurc in the current project
    let luaurc_path = PathBuf::from(".rodeo/.luaurc");
    let alias_value = format!("{pretty_path}");

    let mut rc: serde_json::Value = if luaurc_path.exists() {
        let content = std::fs::read_to_string(&luaurc_path)
            .context("failed to read .rodeo/.luaurc")?;
        serde_json::from_str(&content)
            .context("failed to parse .rodeo/.luaurc")?
    } else {
        std::fs::create_dir_all(".rodeo")
            .context("failed to create .rodeo directory")?;
        serde_json::json!({})
    };

    let aliases = rc
        .as_object_mut()
        .context(".luaurc is not a JSON object")?
        .entry("aliases")
        .or_insert_with(|| serde_json::json!({}));

    aliases
        .as_object_mut()
        .context("aliases is not a JSON object")?
        .insert("rodeo".to_string(), serde_json::Value::String(alias_value));

    let formatted = serde_json::to_string_pretty(&rc)
        .context("failed to serialize .luaurc")?;
    std::fs::write(&luaurc_path, formatted.as_bytes())
        .context("failed to write .rodeo/.luaurc")?;

    tracing::info!("Updated {}", luaurc_path.display());

    Ok(())
}
