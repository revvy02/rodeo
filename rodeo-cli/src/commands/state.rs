use anyhow::Result;
use comfy_table::{presets::NOTHING, ContentArrangement, Table};
use console::style;

use rodeo_client::RodeoClient;
use crate::util::output;

fn short(id: &str) -> String {
    id[..8.min(id.len())].to_string()
}

pub async fn main(host: &str, port: u16, json: bool) -> Result<()> {
    let snapshot = RodeoClient::connect(host, port)?.get_state().await?;

    if json {
        println!("{}", serde_json::to_string_pretty(&snapshot)?);
        return Ok(());
    }

    if snapshot.studios.is_empty() {
        println!("{}", style("STUDIOS").bold());
        println!("  (none connected)");
    } else {
        println!("{}", style("STUDIOS").bold());
        for st in &snapshot.studios {
            let place = if st.place_id != 0 {
                format!("{} (place {})", st.place_name, st.place_id)
            } else {
                st.place_name.clone()
            };
            println!(
                "  {}  {}  {}  {}",
                style(&st.studio_id).cyan(),
                st.studio_mode,
                place,
                st.status,
            );
            for d in &st.doms {
                let user = match (&d.user_name, d.user_id) {
                    (Some(name), Some(id)) => format!("  {name} ({id})"),
                    (Some(name), None) => format!("  {name}"),
                    _ => String::new(),
                };
                println!("    {}  {}{}", d.dom_id, d.dom_kind, user);
            }
        }
    }

    println!();
    println!("{}", style("RUNS").bold());
    if snapshot.processes.is_empty() {
        println!("  (none)");
        return Ok(());
    }

    let mut table = Table::new();
    table
        .load_preset(NOTHING)
        .set_content_arrangement(ContentArrangement::Dynamic);

    table.set_header(vec![
        style("  ID").bold().to_string(),
        style("STATE").bold().to_string(),
        style("TARGET").bold().to_string(),
        style("CONTEXT").bold().to_string(),
        style("DOM").bold().to_string(),
        style("STUDIO").bold().to_string(),
    ]);

    for run in &snapshot.processes {
        let target = if run.target.is_empty() { "-".to_string() } else { run.target.clone() };
        let context = if run.context.is_empty() { "-".to_string() } else { run.context.clone() };
        table.add_row(vec![
            format!("  {}", run.execution_id),
            output::format_state(&run.state),
            target,
            context,
            run.dom_id.as_deref().map(short).unwrap_or_else(|| "-".to_string()),
            run.studio_id.as_deref().map(short).unwrap_or_else(|| "-".to_string()),
        ]);
    }

    println!("{table}");

    Ok(())
}
