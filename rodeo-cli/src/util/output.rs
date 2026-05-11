use console::style;

/// Format a bitset as short colored binary string (e.g. "10010")
pub fn format_bitset_short(bitset: u32) -> String {
    (0..5)
        .map(|i| {
            if (bitset >> i) & 1 == 1 {
                style("1").green().to_string()
            } else {
                style("0").red().to_string()
            }
        })
        .collect()
}

/// Format a process state string with color
pub fn format_state(state: &str) -> String {
    match state {
        "running" => style("running").green().to_string(),
        "queued" => style("queued").yellow().to_string(),
        "error" | "killed" => style(state).red().to_string(),
        "done" => style("done").dim().to_string(),
        "disconnected" => style("disconnected").red().to_string(),
        other => other.to_string(),
    }
}

#[allow(dead_code)]
/// Format a log header like [id: ...] [10010]
pub fn format_short_log(studio_id: &str, bitset: u32, execution_id: Option<&str>) -> String {
    let bitset_str = format_bitset_short(bitset);
    match execution_id {
        Some(eid) => {
            format!(
                "{} {} {}",
                style(format!("[id: {studio_id}]")).dim(),
                format!("[{bitset_str}]"),
                style(format!("[exec: {eid}]")).dim()
            )
        }
        None => format!("{} {}", style(format!("[id: {studio_id}]")).dim(), format!("[{bitset_str}]")),
    }
}
