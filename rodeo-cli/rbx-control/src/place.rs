//! Download a published Roblox place by asset ID.
//!
//! Uses the Roblox auth cookie (via `rbx_cookie`) and the asset delivery API
//! to download the place binary. The cookie is read from Studio's cookie storage
//! (macOS HTTPStorages / Windows Credentials) or the ROBLOSECURITY env var.

use anyhow::{bail, Context, Result};

/// Download a published place by asset ID and return the raw binary content.
pub async fn download_place(place_id: u64) -> Result<Vec<u8>> {
    let cookie = rbx_cookie::get()
        .context("failed to get Roblox auth cookie — is Studio logged in?")?;

    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(5))
        .build()
        .unwrap_or_default();

    // Fetch the asset delivery URL
    let delivery_url = format!(
        "https://assetdelivery.roblox.com/v2/assetId/{place_id}"
    );

    let resp = client
        .get(&delivery_url)
        .header("Cookie", &cookie)
        .send()
        .await
        .context("asset delivery request failed")?;

    if !resp.status().is_success() {
        bail!(
            "asset delivery returned {}: {}",
            resp.status(),
            resp.text().await.unwrap_or_default()
        );
    }

    let body: serde_json::Value = resp.json().await.context("failed to parse asset delivery response")?;

    // Extract CDN location from response
    let cdn_url = body["locations"]
        .as_array()
        .and_then(|locs| locs.first())
        .and_then(|loc| loc["location"].as_str())
        .context("no CDN location in asset delivery response")?;

    // Download from CDN
    let cdn_resp = client
        .get(cdn_url)
        .header("Cookie", &cookie)
        .send()
        .await
        .context("CDN download failed")?;

    if !cdn_resp.status().is_success() {
        bail!("CDN returned {}", cdn_resp.status());
    }

    let bytes = cdn_resp.bytes().await.context("failed to read CDN response")?;
    Ok(bytes.to_vec())
}

/// Stage a place file to `~/Documents/Roblox/server.rbxl` for StartServer.
/// Returns the path to the staged file.
pub fn stage_server_place(content: &[u8]) -> Result<std::path::PathBuf> {
    let dir = dirs::document_dir()
        .context("could not find Documents directory")?
        .join("Roblox");
    std::fs::create_dir_all(&dir).context("failed to create ~/Documents/Roblox")?;
    let path = dir.join("server.rbxl");
    std::fs::write(&path, content).context("failed to write server.rbxl")?;
    Ok(path)
}

/// Stage a local .rbxl file by copying it to `~/Documents/Roblox/server.rbxl`.
pub fn stage_local_place(source: &std::path::Path) -> Result<std::path::PathBuf> {
    let dir = dirs::document_dir()
        .context("could not find Documents directory")?
        .join("Roblox");
    std::fs::create_dir_all(&dir).context("failed to create ~/Documents/Roblox")?;
    let dest = dir.join("server.rbxl");
    std::fs::copy(source, &dest).context("failed to copy place to server.rbxl")?;
    Ok(dest)
}
