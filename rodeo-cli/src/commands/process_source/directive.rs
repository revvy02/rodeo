use regex::Regex;
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::path::Path;

/// Resolve a script name to a file path.
/// Simple names (no path separator, no extension) are resolved to .rodeo/{name}.luau
pub fn resolve_script_path(script_arg: &str) -> String {
    // If it already has a path separator or extension, use as-is
    if script_arg.contains('/') || script_arg.contains('\\') || script_arg.contains('.') {
        return script_arg.to_string();
    }

    // Try .rodeo/{name}.luau
    let rodeo_path = format!(".rodeo/{script_arg}.luau");
    if Path::new(&rodeo_path).is_file() {
        return rodeo_path;
    }

    // Fall back to original
    script_arg.to_string()
}

/// Parse @rodeo run directive flags from a script's content.
/// Looks for `@rodeo run --key value -- args` in comments.
/// Returns parsed flags as a map, and script args if found.
pub fn parse_directive(content: &str) -> Option<DirectiveResult> {
    let re = Regex::new(r"@rodeo\s+run\s+([^\n\]]+)").ok()?;
    let captures = re.captures(content)?;
    let directive_str = captures.get(1)?.as_str().trim();

    Some(parse_directive_flags(directive_str))
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DirectiveResult {
    pub flags: HashMap<String, DirectiveValue>,
    pub script_args: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DirectiveValue {
    Bool(bool),
    String(String),
    Number(i64),
    List(Vec<String>),
}

impl DirectiveValue {
    pub fn as_bool(&self) -> Option<bool> {
        match self {
            DirectiveValue::Bool(b) => Some(*b),
            _ => None,
        }
    }

    pub fn as_str(&self) -> Option<&str> {
        match self {
            DirectiveValue::String(s) => Some(s),
            _ => None,
        }
    }
}

/// Known flags that can appear multiple times (accumulated into a list).
const REPEATABLE_FLAGS: &[&str] = &["fflag.override"];

/// Parse directive flags string like "--bundle --context server -- arg1 arg2"
pub fn parse_directive_flags(directive_str: &str) -> DirectiveResult {
    let mut result = DirectiveResult::default();
    let parts: Vec<&str> = directive_str.split_whitespace().collect();
    let mut i = 0;
    let mut in_args = false;

    while i < parts.len() {
        let part = parts[i];

        if part == "--" {
            in_args = true;
            i += 1;
            continue;
        }

        if in_args {
            result.script_args.push(part.to_string());
            i += 1;
            continue;
        }

        if let Some(flag_name) = part.strip_prefix("--") {
            // Check if next part is a value or another flag
            if i + 1 < parts.len() && !parts[i + 1].starts_with("--") {
                let value = parts[i + 1];

                if REPEATABLE_FLAGS.contains(&flag_name) {
                    // Accumulate into a list
                    match result.flags.get_mut(flag_name) {
                        Some(DirectiveValue::List(list)) => {
                            list.push(value.to_string());
                        }
                        _ => {
                            result.flags.insert(
                                flag_name.to_string(),
                                DirectiveValue::List(vec![value.to_string()]),
                            );
                        }
                    }
                } else if let Ok(n) = value.parse::<i64>() {
                    result
                        .flags
                        .insert(flag_name.to_string(), DirectiveValue::Number(n));
                } else {
                    result
                        .flags
                        .insert(flag_name.to_string(), DirectiveValue::String(value.to_string()));
                }
                i += 2;
            } else {
                // Boolean flag
                result
                    .flags
                    .insert(flag_name.to_string(), DirectiveValue::Bool(true));
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    result
}
