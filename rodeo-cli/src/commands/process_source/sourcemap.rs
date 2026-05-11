use anyhow::{Context, Result};
use serde_json::Value;

/// Load and parse a sourcemap file
pub fn load_sourcemap(path: &str) -> Result<Value> {
    let content =
        std::fs::read_to_string(path).context("failed to read sourcemap")?;
    serde_json::from_str(&content).context("failed to parse sourcemap")
}

/// Search the sourcemap tree for a file path, returning the Roblox instance path
pub fn find_instance_path(sourcemap: &Value, file_path: &str) -> Option<String> {
    // Normalize path separators
    let normalized = file_path.replace('\\', "/");
    search_tree(sourcemap, &normalized, &mut Vec::new())
}

fn search_tree(node: &Value, target: &str, path: &mut Vec<String>) -> Option<String> {
    // Check if this node's filePaths contain the target
    if let Some(file_paths) = node.get("filePaths") {
        if let Some(arr) = file_paths.as_array() {
            for fp in arr {
                if let Some(s) = fp.as_str() {
                    let normalized = s.replace('\\', "/");
                    if normalized.ends_with(target) || target.ends_with(&normalized) {
                        // Build instance path
                        return Some(build_instance_path(path));
                    }
                }
            }
        }
    }

    // Recurse into children
    if let Some(children) = node.get("children") {
        if let Some(arr) = children.as_array() {
            for child in arr {
                if let Some(name) = child.get("name").and_then(|n| n.as_str()) {
                    path.push(name.to_string());
                    if let Some(result) = search_tree(child, target, path) {
                        return Some(result);
                    }
                    path.pop();
                }
            }
        }
    }

    None
}

fn build_instance_path(segments: &[String]) -> String {
    if segments.is_empty() {
        return "game".to_string();
    }
    let mut result = "game".to_string();
    for seg in segments {
        result.push_str(&format!("[\"{seg}\"]"));
    }
    result
}
