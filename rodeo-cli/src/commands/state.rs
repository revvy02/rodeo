use anyhow::Result;
use comfy_table::{presets::NOTHING, ContentArrangement, Table};
use console::style;

use rodeo_client::RodeoClient;
use crate::util::output;

fn short(id: &str) -> String {
    id[..8.min(id.len())].to_string()
}

fn new_table(headers: &[&str]) -> Table {
    let mut table = Table::new();
    table
        .load_preset(NOTHING)
        .set_content_arrangement(ContentArrangement::Dynamic);
    table.set_header(headers.iter().map(|h| style(*h).bold().to_string()).collect::<Vec<_>>());
    table
}

pub async fn main(host: &str, port: u16, json: bool) -> Result<()> {
    let snapshot = RodeoClient::connect(host, port)?.get_state().await?;

    if json {
        println!("{}", serde_json::to_string_pretty(&snapshot)?);
        return Ok(());
    }

    // Normalized, flat tables joined by the short studio id: studio-level
    // facts once in STUDIOS, one row per DOM in DOMS referencing its studio.
    println!("{}", style("STUDIOS").bold());
    if snapshot.studios.is_empty() {
        println!("  (none connected)");
    } else {
        let mut table = new_table(&["STUDIO", "MODE", "PLACE", "STATUS"]);
        for st in &snapshot.studios {
            let place = if st.place_id != 0 {
                format!("{} ({})", st.place_name, st.place_id)
            } else {
                st.place_name.clone()
            };
            table.add_row(vec![
                short(&st.studio_id),
                st.studio_mode.clone(),
                place,
                st.status.clone(),
            ]);
        }
        println!("{table}");
    }

    println!();
    println!("{}", style("DOMS").bold());
    let has_doms = snapshot.studios.iter().any(|s| !s.doms.is_empty());
    if !has_doms {
        println!("  (none)");
    } else {
        let mut table = new_table(&["DOM", "KIND", "STUDIO", "USER"]);
        for st in &snapshot.studios {
            for d in &st.doms {
                let user = match (&d.user_name, d.user_id) {
                    (Some(name), Some(id)) => format!("{name} ({id})"),
                    (Some(name), None) => name.clone(),
                    _ => "-".to_string(),
                };
                table.add_row(vec![
                    short(&d.dom_id),
                    d.dom_kind.clone(),
                    short(&st.studio_id),
                    user,
                ]);
            }
        }
        println!("{table}");
    }

    println!();
    println!("{}", style("RUNS").bold());
    if snapshot.processes.is_empty() {
        println!("  (none)");
        return Ok(());
    }

    let mut table = new_table(&["ID", "STATE", "MODE", "KIND", "CONTEXT", "DOM", "STUDIO"]);
    for run in &snapshot.processes {
        let dash = |s: &str| if s.is_empty() { "-".to_string() } else { s.to_string() };
        table.add_row(vec![
            run.execution_id.clone(),
            output::format_state(&run.state),
            dash(&run.mode),
            dash(&run.dom_kind),
            dash(&run.context),
            run.dom_id.as_deref().map(short).unwrap_or_else(|| "-".to_string()),
            run.studio_id.as_deref().map(short).unwrap_or_else(|| "-".to_string()),
        ]);
    }
    println!("{table}");

    Ok(())
}
