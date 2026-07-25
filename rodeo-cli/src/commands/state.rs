use anyhow::Result;
use comfy_table::{presets::NOTHING, ContentArrangement, Table};
use console::style;

use rodeo_client::RodeoClient;
use crate::util::output;

fn short(id: &str) -> String {
    id[..8.min(id.len())].to_string()
}

/// Render a path for the table: relative to the CLI's CWD when it's inside it
/// (keeps the common `.rodeo/.temp/...` case short), absolute otherwise,
/// "-" when absent (manually-opened Studios have no launch record).
fn display_path(p: Option<&str>) -> String {
    let Some(p) = p else { return "-".to_string() };
    if let Ok(cwd) = std::env::current_dir() {
        if let Ok(rel) = std::path::Path::new(p).strip_prefix(&cwd) {
            return rel.to_string_lossy().to_string();
        }
    }
    p.to_string()
}

fn new_table(headers: &[&str]) -> Table {
    let mut table = Table::new();
    table
        .load_preset(NOTHING)
        .set_content_arrangement(ContentArrangement::Dynamic);
    table.set_header(headers.iter().map(|h| style(*h).bold().to_string()).collect::<Vec<_>>());
    table
}

/// Print a section table; an empty section keeps its header row visible with a
/// single all-"-" placeholder row instead of collapsing to "(none)".
fn print_section(title: &str, columns: usize, table: &mut Table) {
    println!("{}", style(title).bold());
    if table.row_iter().next().is_none() {
        table.add_row(vec!["-".to_string(); columns]);
    }
    println!("{table}");
}

pub async fn main(host: &str, port: u16, json: bool) -> Result<()> {
    let snapshot = RodeoClient::connect(host, port)?.get_state().await?;

    if json {
        println!("{}", serde_json::to_string_pretty(&snapshot)?);
        return Ok(());
    }

    // Normalized, flat tables joined by the short studio id: studio-level
    // facts once in the studio sections, one row per DOM in DOMS referencing
    // its studio. Local-file and live-place studios split into their own
    // sections — path columns only apply to the former, the place-id column
    // only to the latter.
    let (local, live): (Vec<_>, Vec<_>) = snapshot.studios.iter().partition(|st| st.place_id == 0);

    let mut table = new_table(&["ID", "MODE", "SOURCE_PATH", "WORKING_PATH", "STATUS"]);
    for st in &local {
        table.add_row(vec![
            short(&st.studio_id),
            st.studio_mode.clone(),
            display_path(st.source_path.as_deref()),
            display_path(st.working_path.as_deref()),
            st.status.clone(),
        ]);
    }
    print_section("LOCAL", 5, &mut table);

    println!();
    let mut table = new_table(&["ID", "MODE", "PLACE", "STATUS"]);
    for st in &live {
        table.add_row(vec![
            short(&st.studio_id),
            st.studio_mode.clone(),
            format!("{} ({})", st.place_name, st.place_id),
            st.status.clone(),
        ]);
    }
    print_section("UPLOADED", 4, &mut table);

    println!();
    let mut table = new_table(&["ID", "KIND", "STUDIO", "USER"]);
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
    print_section("DOMS", 4, &mut table);

    println!();
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
    print_section("RUNS", 7, &mut table);

    Ok(())
}
