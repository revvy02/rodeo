use regex::Regex;
use std::path::Path;

/// Resolve a script name to a file path.
/// Simple names (no path separator, no extension) are resolved to .rodeo/{name}.luau
pub fn resolve_script_path(script_arg: &str) -> String {
    if script_arg.contains('/') || script_arg.contains('\\') || script_arg.contains('.') {
        return script_arg.to_string();
    }

    let rodeo_path = format!(".rodeo/{script_arg}.luau");
    if Path::new(&rodeo_path).is_file() {
        return rodeo_path;
    }

    script_arg.to_string()
}

/// Raw argv tokens parsed from a script's `@rodeo run …` directive header.
/// The parent splices `flag_args` into argv between the `run` subcommand and
/// user-supplied args; clap then handles validation, type conversion, and
/// override semantics. `script_args` (after the directive's `--`) are passed
/// through separately and applied only if the user didn't supply any.
pub struct DirectiveTokens {
    pub flag_args: Vec<String>,
    pub script_args: Vec<String>,
}

/// Parse `@rodeo run --flag value -- arg1 arg2` from a script header into
/// argv-style tokens. Returns None if no directive line is present.
pub fn parse_directive(content: &str) -> Option<DirectiveTokens> {
    let re = Regex::new(r"@rodeo\s+run\s+([^\n\]]+)").ok()?;
    let captures = re.captures(content)?;
    let directive_str = captures.get(1)?.as_str().trim();

    let mut flag_args = Vec::new();
    let mut script_args = Vec::new();
    let mut in_script_args = false;
    for tok in directive_str.split_whitespace() {
        if !in_script_args && tok == "--" {
            in_script_args = true;
            continue;
        }
        if in_script_args {
            script_args.push(tok.to_string());
        } else {
            flag_args.push(tok.to_string());
        }
    }

    Some(DirectiveTokens { flag_args, script_args })
}
