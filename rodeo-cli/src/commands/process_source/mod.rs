pub mod adapters;
pub mod bundle;
pub mod directive;
pub mod execution;
pub mod source;
pub mod sourcemap;

use anyhow::{bail, Result};
use serde::{Serialize, Deserialize};

#[derive(Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ProcessedSource {
    pub script: String,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub script_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub instance_path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none", default)]
    pub directives: Option<directive::DirectiveResult>,
}

/// Process source directly (no subprocess). Used by `run.rs`.
pub fn process(
    script: Option<String>,
    source_arg: Option<String>,
    sourcemap: Option<String>,
) -> Result<ProcessedSource> {
    if let Some(ref src) = source_arg {
        // Materialize inline source to a temp `.luau` file under CWD so
        // darklua's bundle pass has an anchor for relative-path require
        // resolution. Same pipeline as file-mode: bundle (inlines fs deps)
        // → inline_shims (resolves @rodeo/@lune) → ensure_return.
        let tmp_path = std::env::current_dir()
            .unwrap_or_else(|_| std::path::PathBuf::from("."))
            .join(format!(".rodeo-inline-{}.luau", uuid::Uuid::new_v4()));
        std::fs::write(&tmp_path, src)
            .map_err(|e| anyhow::anyhow!("cannot write inline-source temp file: {e}"))?;

        let opts = bundle::BundleOptions {
            sourcemap: sourcemap.clone(),
            verbose: false,
        };
        let bundle_result = bundle::bundle(tmp_path.to_str().unwrap_or(""), &opts);
        let _ = std::fs::remove_file(&tmp_path);
        let bundled = bundle_result?;

        let shimmed = bundle::inline_shims(&bundled)?;
        let script = source::ensure_return(&shimmed);
        Ok(ProcessedSource {
            script,
            script_path: None,
            instance_path: None,
            directives: None,
        })
    } else if let Some(ref file) = script {
        // File: resolve path, parse directives, bundle, shim, ensure_return, resolve instance
        let resolved = directive::resolve_script_path(file);
        let content = std::fs::read_to_string(&resolved)
            .map_err(|e| anyhow::anyhow!("cannot read '{}': {}", resolved, e))?;

        // Parse directives
        let directives = directive::parse_directive(&content);

        // Bundle
        let opts = bundle::BundleOptions {
            sourcemap: sourcemap.clone(),
            verbose: false,
        };
        let bundled = bundle::bundle(&resolved, &opts)?;

        // Shim injection + ensure_return
        let shimmed = bundle::inline_shims(&bundled)?;
        let script = source::ensure_return(&shimmed);

        // Instance resolution
        let script_path = Some(execution::compute_relative_path(&resolved));
        let instance_path = execution::resolve_instance_path(
            sourcemap.as_deref(),
            Some(&resolved),
        );

        Ok(ProcessedSource {
            script,
            script_path,
            instance_path,
            directives,
        })
    } else {
        bail!("either a script file or --source must be provided");
    }
}

/// Entry point for __process_source subcommand (outputs JSON to stdout).
pub fn main(
    script: Option<String>,
    source_arg: Option<String>,
    sourcemap: Option<String>,
) -> Result<()> {
    let result = process(script, source_arg, sourcemap)?;
    let json = serde_json::to_string(&result)?;
    println!("{json}");
    Ok(())
}
