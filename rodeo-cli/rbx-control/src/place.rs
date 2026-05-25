//! Download a published Roblox place by asset ID.
//!
//! Uses the Roblox auth cookie (via `rbx_cookie`) and the asset delivery API
//! to download the place binary. The cookie is read from Studio's cookie storage
//! (macOS HTTPStorages / Windows Credentials) or the ROBLOSECURITY env var.

use anyhow::{bail, Context, Result};
use std::error::Error;

/// A published Roblox place fetched from the asset-delivery + universe APIs,
/// bundling the binary content with the identifiers needed by Studio's
/// `-task StartServer` / `-task StartClient` flags (placeId, universeId,
/// placeVersion). Returned by [`download_published_place`].
pub struct PublishedPlace {
    pub content: Vec<u8>,
    pub universe_id: u64,
    pub place_version: u32,
}

/// Download a published place by asset ID and return the raw binary content.
///
/// Kept for callers that only need the file bytes. New launch paths should use
/// [`download_published_place`] instead, which also resolves the universe and
/// version metadata needed to seed Studio with non-zero identity flags.
pub async fn download_place(place_id: u64) -> Result<Vec<u8>> {
    let cookie = roblox_cookie()?;
    let client = http_client();
    let (bytes, _version) = download_place_inner(&client, &cookie, place_id).await?;
    Ok(bytes)
}

/// Download a published place + resolve its universe id and place version.
///
/// Combines the existing asset-delivery v2 CDN flow with two extra metadata
/// lookups (universe lookup endpoint + version extraction or develop.roblox
/// fallback). All calls share the same `rbx_cookie` auth as `download_place`.
pub async fn download_published_place(place_id: u64) -> Result<PublishedPlace> {
    let cookie = roblox_cookie()?;
    let client = http_client();

    // 1. Download the place binary + try to recover the version inline from
    //    the asset-delivery response (single round-trip if the field is there).
    let (content, version_from_delivery) =
        download_place_inner(&client, &cookie, place_id).await?;

    // 2. Universe lookup. Public endpoint, cookie-authed for owned places.
    let universe_id = resolve_universe_id(&client, &cookie, place_id).await?;

    // 3. Place version — prefer Open Cloud /versions (most reliable, needs
    //    api key), then inline asset-delivery value, then develop API. Falls
    //    back to 0 which Studio treats as "latest" — that path still launches
    //    fine, the experiment just can't pin a specific version.
    let api_key = std::env::var("RODEO_OPEN_CLOUD_API_KEY").ok();
    let place_version = match api_key {
        Some(key) => match resolve_place_version_open_cloud(&client, &key, place_id).await {
            Some(v) => v,
            None => version_from_delivery
                .unwrap_or_else(|| 0),
        },
        None => match version_from_delivery {
            Some(v) => v,
            None => resolve_place_version_fallback(&client, &cookie, place_id).await,
        },
    };

    tracing::info!(place_id, universe_id, place_version, "resolved published place");
    Ok(PublishedPlace { content, universe_id, place_version })
}

fn roblox_cookie() -> Result<String> {
    rbx_cookie::get()
        .context("failed to get Roblox auth cookie — is Studio logged in?")
}

fn http_client() -> reqwest::Client {
    reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(60))
        .gzip(true)
        .build()
        .unwrap_or_default()
}

/// Asset-delivery + CDN download. Returns `(bytes, Option<place_version>)` — if
/// the asset-delivery v2 response includes an `assetVersionNumber`-shaped field,
/// we extract it here so callers don't need a second HTTP round-trip.
async fn download_place_inner(
    client: &reqwest::Client,
    cookie: &str,
    place_id: u64,
) -> Result<(Vec<u8>, Option<u32>)> {
    let delivery_url = format!("https://assetdelivery.roblox.com/v2/assetId/{place_id}");

    let resp = client
        .get(&delivery_url)
        .header("Cookie", cookie)
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

    let body: serde_json::Value = resp
        .json()
        .await
        .context("failed to parse asset delivery response")?;

    // Log top-level keys once so we can confirm the field name carrying the
    // version in real responses (assetVersionNumber vs version vs other).
    if let Some(obj) = body.as_object() {
        let keys: Vec<&str> = obj.keys().map(|k| k.as_str()).collect();
        tracing::debug!(place_id, ?keys, "asset delivery v2 response keys");
    }

    // Try to extract a version number from common field names. Roblox isn't
    // 100% consistent — print what we find on first run for confirmation.
    let version = extract_version(&body);

    let cdn_url = body["locations"]
        .as_array()
        .and_then(|locs| locs.first())
        .and_then(|loc| loc["location"].as_str())
        .context("no CDN location in asset delivery response")?;

    let cdn_resp = client
        .get(cdn_url)
        .header("Cookie", cookie)
        .send()
        .await
        .context("CDN download failed")?;

    if !cdn_resp.status().is_success() {
        bail!("CDN returned {}", cdn_resp.status());
    }

    let bytes = match cdn_resp.bytes().await {
        Ok(b) => b,
        Err(e) => {
            tracing::error!(place_id, error = %e, source = ?e.source(), "CDN body read failed");
            return Err(anyhow::anyhow!("failed to read CDN response: {}", e));
        }
    };
    Ok((bytes.to_vec(), version))
}

/// Hunt for a version-shaped integer in the asset-delivery response. Checks a
/// small set of candidate field names because Roblox isn't consistent about
/// which one carries the published place version.
fn extract_version(body: &serde_json::Value) -> Option<u32> {
    const CANDIDATES: &[&str] = &[
        "assetVersionNumber",
        "AssetVersionNumber",
        "version",
        "Version",
        "placeVersion",
        "PlaceVersion",
    ];
    for key in CANDIDATES {
        if let Some(v) = body.get(*key).and_then(|v| v.as_u64()) {
            return Some(v as u32);
        }
    }
    None
}

/// `GET https://apis.roblox.com/universes/v1/places/<placeId>/universe`.
/// Public endpoint, cookie-authed (avoids occasional 401s on private places).
/// Response shape: `{"universeId": <number>}` — we also accept `id`/`Id` as
/// defensive fallbacks in case the API ever shifts on us.
async fn resolve_universe_id(
    client: &reqwest::Client,
    cookie: &str,
    place_id: u64,
) -> Result<u64> {
    let url = format!(
        "https://apis.roblox.com/universes/v1/places/{place_id}/universe"
    );
    let resp = client
        .get(&url)
        .header("Cookie", cookie)
        .send()
        .await
        .context("universe lookup request failed")?;

    if !resp.status().is_success() {
        bail!(
            "universe lookup returned {}: {}",
            resp.status(),
            resp.text().await.unwrap_or_default()
        );
    }

    let body: serde_json::Value = resp
        .json()
        .await
        .context("failed to parse universe lookup response")?;

    if let Some(obj) = body.as_object() {
        let keys: Vec<&str> = obj.keys().map(|k| k.as_str()).collect();
        tracing::debug!(place_id, ?keys, "universe lookup response keys");
    }

    let raw = body
        .get("universeId")
        .or_else(|| body.get("UniverseId"))
        .or_else(|| body.get("id"))
        .or_else(|| body.get("Id"));

    match raw.and_then(|v| v.as_u64()) {
        Some(uid) => Ok(uid),
        None => {
            tracing::debug!(place_id, ?raw, "universeId field present but not a number");
            bail!(
                "universe lookup returned {:?} for universeId (place may not be the root of a published universe, or may be private)",
                raw
            );
        }
    }
}

/// Preferred resolver — Open Cloud /versions endpoint via x-api-key.
/// Returns `None` on any error so the caller can fall back. Pattern from
/// rensselaer's `downloadLatestSavedPlace` ([downloadPlace.luau:103-135]).
async fn resolve_place_version_open_cloud(
    client: &reqwest::Client,
    api_key: &str,
    place_id: u64,
) -> Option<u32> {
    let url = format!(
        "https://apis.roblox.com/assets/v1/assets/{place_id}/versions?sortOrder=Desc&limit=1"
    );
    let resp = match client
        .get(&url)
        .header("Accept", "application/json")
        .header("x-api-key", api_key)
        .send()
        .await
    {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!(place_id, %e, "open cloud /versions request failed");
            return None;
        }
    };
    if !resp.status().is_success() {
        tracing::warn!(place_id, status = %resp.status(), "open cloud /versions non-success");
        return None;
    }
    let body: serde_json::Value = match resp.json().await {
        Ok(b) => b,
        Err(e) => {
            tracing::warn!(place_id, %e, "open cloud /versions parse failed");
            return None;
        }
    };
    let path = body
        .get("assetVersions")
        .and_then(|v| v.as_array())
        .and_then(|arr| arr.first())
        .and_then(|entry| entry.get("path"))
        .and_then(|p| p.as_str())?;
    // Path format: "assets/<id>/versions/<N>" — extract trailing integer.
    let version_str = path.rsplit('/').next()?;
    let version: u64 = version_str.parse().ok()?;
    tracing::debug!(place_id, version, "open cloud /versions resolved");
    Some(version as u32)
}

/// Cookie-only fallback used when the asset-delivery body doesn't carry a
/// version field and the user hasn't provided an Open Cloud API key.
/// Tries `develop.roblox.com/v2/places/<placeId>` (place-specific metadata
/// returns `currentSavedVersion`). If that also fails, returns 0 — Studio
/// treats `-placeVersion 0` as "latest" and we still get the staged file, so
/// the launch can proceed even if we couldn't pin the integer.
async fn resolve_place_version_fallback(
    client: &reqwest::Client,
    cookie: &str,
    place_id: u64,
) -> u32 {
    let url = format!("https://develop.roblox.com/v2/places/{place_id}");
    let resp = match client.get(&url).header("Cookie", cookie).send().await {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!(place_id, %e, "place metadata request failed; using placeVersion=0");
            return 0;
        }
    };

    if !resp.status().is_success() {
        tracing::warn!(
            place_id,
            status = %resp.status(),
            "develop.roblox.com/v2/places returned non-success; using placeVersion=0"
        );
        return 0;
    }

    let body: serde_json::Value = match resp.json().await {
        Ok(b) => b,
        Err(e) => {
            tracing::warn!(place_id, %e, "place metadata parse failed; using placeVersion=0");
            return 0;
        }
    };

    if let Some(obj) = body.as_object() {
        let keys: Vec<&str> = obj.keys().map(|k| k.as_str()).collect();
        tracing::debug!(place_id, ?keys, "develop.roblox.com/v2/places response keys");
    }

    let version = body
        .get("currentSavedVersion")
        .or_else(|| body.get("CurrentSavedVersion"))
        .or_else(|| body.get("placeVersion"))
        .or_else(|| body.get("PlaceVersion"))
        .or_else(|| body.get("version"))
        .or_else(|| body.get("Version"))
        .and_then(|v| v.as_u64());

    match version {
        Some(v) => v as u32,
        None => {
            tracing::warn!(place_id, "no version field in place metadata; using placeVersion=0");
            0
        }
    }
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
