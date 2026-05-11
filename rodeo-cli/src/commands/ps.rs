use anyhow::Result;
use comfy_table::{presets::NOTHING, ContentArrangement, Table};
use console::style;

use rodeo_client::RodeoClient;
use crate::util::output;

pub async fn main(host: &str, port: u16) -> Result<()> {
    let procs = RodeoClient::connect(host, port)?.list_processes().await?;

    if procs.is_empty() {
        tracing::info!("No active processes");
        return Ok(());
    }

    let mut table = Table::new();
    table
        .load_preset(NOTHING)
        .set_content_arrangement(ContentArrangement::Dynamic);

    table.set_header(vec![
        style("ID").bold().to_string(),
        style("NAME").bold().to_string(),
        style("STATE").bold().to_string(),
        style("CONTEXT").bold().to_string(),
        style("TARGET").bold().to_string(),
        style("EXECUTION").bold().to_string(),
    ]);

    for proc in &procs {
        let id = format!("#{}", proc.process_id);
        let name = proc.name.as_deref().unwrap_or("-").to_string();
        let state = output::format_state(&proc.state);
        let context = proc.target.clone();
        let vm = proc
            .vm_bitset
            .map(|b| output::format_bitset_short(b))
            .unwrap_or_else(|| "-".to_string());
        let eid = style(&proc.execution_id).dim().to_string();

        table.add_row(vec![id, name, state, context, vm, eid]);
    }

    println!("{table}");

    Ok(())
}
