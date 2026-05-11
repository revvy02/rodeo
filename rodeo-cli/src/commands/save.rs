use anyhow::{bail, Context, Result};
use rodeo_client::RodeoClient;

pub async fn main(host: &str, port: u16, out: Option<String>) -> Result<()> {
    let result = RodeoClient::connect(host, port)?.save_default().await?;

    tracing::info!("Studio place saved");

    if let Some(out_path) = out {
        if let Some(src_path) = result.path {
            // Brief delay for Studio to finish writing the file
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            std::fs::copy(&src_path, &out_path)
                .context(format!("failed to copy {src_path} to {out_path}"))?;
            tracing::info!("Copied to {out_path}");
        } else {
            bail!("serve did not report a place file path");
        }
    }

    Ok(())
}
