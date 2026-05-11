use rodeo_proto as proto;


/// Build a proto::LogFilter from the run command flags
pub fn build_log_filter(
    no_warn: bool,
    no_error: bool,
    no_info: bool,
    no_print: bool,
    no_output: bool,
) -> proto::LogFilter {
    if no_output {
        return proto::LogFilter {
            enable_warn: false,
            enable_error: false,
            enable_info: false,
            enable_output: false,
            enable_logs: false,
            ..Default::default()
        };
    }

    proto::LogFilter {
        enable_warn: !no_warn,
        enable_error: !no_error,
        enable_info: !no_info,
        enable_output: !no_print,
        enable_logs: true,
        ..Default::default()
    }
}

/// Resolve instance path from sourcemap if available
pub fn resolve_instance_path(
    sourcemap_path: Option<&str>,
    script_path: Option<&str>,
) -> Option<String> {
    let sm_path = sourcemap_path?;
    let s_path = script_path?;

    let sourcemap = super::sourcemap::load_sourcemap(sm_path).ok()?;
    super::sourcemap::find_instance_path(&sourcemap, s_path)
}

/// Compute relative path from cwd for module naming in Studio
pub fn compute_relative_path(script_path: &str) -> String {
    let abs = std::fs::canonicalize(script_path).unwrap_or_else(|_| script_path.into());
    let cwd = std::env::current_dir().unwrap_or_default();
    pathdiff::diff_paths(&abs, &cwd)
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| script_path.to_string())
}

