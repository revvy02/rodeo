use anyhow::Result;
use rodeo_client::RodeoClient;

pub async fn main(id: u32, host: &str, port: u16) -> Result<()> {
    RodeoClient::connect(host, port)?.kill(id).await?;
    tracing::info!("Killed process #{id}");
    Ok(())
}
