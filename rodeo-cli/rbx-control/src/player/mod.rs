use anyhow::{Context, Result};

use crate::fflags::FflagConfig;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Options for launching the Roblox Player.
#[derive(Clone, Debug)]
pub struct PlayerOptions {
    pub place_id: u64,
    pub job_id: Option<String>,
    pub fflags: FflagConfig,
    pub detached: bool,
}

// ---------------------------------------------------------------------------
// Player
// ---------------------------------------------------------------------------

/// Handle to a launched Roblox Player instance.
///
/// Owns the process lifecycle and FFlag restoration.
/// Drop triggers cleanup (restore fflags → kill).
pub struct Player {
    handle: std::sync::Mutex<Option<launch_control::Child>>,
    fflag_handle: Option<crate::fflags::FflagHandle>,
    detached: bool,
}

impl Player {
    /// Launch the Roblox Player to join a place.
    pub fn launch(opts: PlayerOptions) -> Result<Self> {
        // Apply fflags before launching (Player reads them at startup)
        let fflag_handle =
            if !opts.fflags.overrides.is_empty() || opts.fflags.file.is_some() {
                crate::fflags::apply(
                    crate::fflags::FflagTarget::Player,
                    &opts.fflags.overrides,
                    opts.fflags.file.as_deref(),
                )?
            } else {
                None
            };

        let app_path = player_application_path()?;
        let mut url = format!("roblox://placeId={}", opts.place_id);
        if let Some(ref job_id) = opts.job_id {
            url.push_str(&format!("&gameInstanceId={job_id}"));
        }

        tracing::info!(place_id = opts.place_id, "Launching Roblox Player...");

        let handle = launch_control::Command::new(&app_path)
            .url(&url)
            .spawn()
            .context("failed to launch Roblox Player")?;

        tracing::info!(pid = handle.id(), "Roblox Player launched");

        Ok(Player {
            handle: std::sync::Mutex::new(Some(handle)),
            fflag_handle,
            detached: opts.detached,
        })
    }

    /// Check if the Player process is still running.
    pub fn is_running(&self) -> bool {
        match self.handle.lock().unwrap().as_mut() {
            Some(handle) => handle.try_wait().ok().map_or(true, |s| s.is_none()),
            None => false,
        }
    }

    /// Terminate the Player process.
    pub fn kill(&self) {
        if let Some(ref mut handle) = *self.handle.lock().unwrap() {
            let _ = handle.kill();
        }
    }

    /// Full cleanup: restore fflags → kill (unless detached).
    pub fn cleanup(&self) {
        // Restore fflags (always — system-wide state)
        if let Some(ref handle) = self.fflag_handle {
            handle.restore();
        }
        // Kill (skip if detached)
        if !self.detached {
            self.kill();
        }
    }
}

impl Drop for Player {
    fn drop(&mut self) {
        self.cleanup();
    }
}

// ---------------------------------------------------------------------------
// Player binary location
// ---------------------------------------------------------------------------

/// Get the path to the Roblox Player application.
pub fn player_application_path() -> Result<String> {
    #[cfg(target_os = "macos")]
    {
        let path = "/Applications/Roblox.app";
        if std::path::Path::new(path).exists() {
            Ok(path.to_string())
        } else {
            anyhow::bail!("Roblox Player not found at {path}")
        }
    }

    #[cfg(target_os = "windows")]
    {
        use std::path::PathBuf;
        // Player is at %LOCALAPPDATA%/Roblox/Versions/{version}/RobloxPlayerBeta.exe
        let local_app = std::env::var("LOCALAPPDATA")
            .context("LOCALAPPDATA not set")?;
        let versions_dir = PathBuf::from(local_app).join("Roblox").join("Versions");
        let mut latest: Option<PathBuf> = None;
        if let Ok(entries) = std::fs::read_dir(&versions_dir) {
            for entry in entries.flatten() {
                let p = entry.path();
                if p.join("RobloxPlayerBeta.exe").exists() {
                    latest = Some(p.join("RobloxPlayerBeta.exe"));
                }
            }
        }
        latest
            .map(|p| p.to_string_lossy().to_string())
            .context("could not find Roblox Player")
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        anyhow::bail!("Roblox Player not supported on this platform")
    }
}
