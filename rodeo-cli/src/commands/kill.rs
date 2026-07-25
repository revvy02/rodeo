use anyhow::{bail, Result};
use rodeo_client::RodeoClient;

fn short(id: &str) -> &str {
    &id[..8.min(id.len())]
}

/// `rodeo kill <id>` takes a run id or a studio id (prefixes accepted) and
/// resolves which kind it is against the state snapshot: a unique run match
/// kills the run, a unique studio match closes the Studio. Ambiguity across
/// or within kinds is an error listing the candidates.
pub async fn main(id: &str, host: &str, port: u16) -> Result<()> {
    // Guard before prefix matching: starts_with("") is true for everything.
    if id.is_empty() {
        bail!("provide a run ID or Studio ID (see `rodeo state`)");
    }
    let client = RodeoClient::connect(host, port)?;
    let snapshot = client.get_state().await?;

    let run_matches: Vec<&str> = snapshot
        .processes
        .iter()
        .filter(|run| run.execution_id.starts_with(id))
        .map(|run| run.execution_id.as_str())
        .collect();
    let studio_matches: Vec<_> = snapshot
        .studios
        .iter()
        .filter(|st| st.studio_id.starts_with(id))
        .collect();

    match (run_matches.as_slice(), studio_matches.as_slice()) {
        ([], []) => bail!("no run or Studio with id '{id}' (see `rodeo state`)"),
        ([run_id], []) => {
            client.kill(run_id).await?;
            tracing::info!("Killed run {run_id}");
        }
        ([], [studio]) => {
            // CloseStudio wants the launch session_guid. Manually-connected
            // studios have no session — rodeo didn't launch them, so it can't
            // close them.
            let Some(session_guid) = studio.session_id.clone() else {
                bail!(
                    "Studio {} was not launched by rodeo (no session) — close it from Studio directly",
                    short(&studio.studio_id)
                );
            };
            client.close_studio_raw(&session_guid).await?;
            tracing::info!("Closed Studio {}", short(&studio.studio_id));
        }
        (runs, studios) => {
            let mut candidates: Vec<String> =
                runs.iter().map(|r| format!("run {r}")).collect();
            candidates.extend(studios.iter().map(|st| format!("studio {}", short(&st.studio_id))));
            bail!("'{id}' is ambiguous: {}", candidates.join(", "));
        }
    }
    Ok(())
}
