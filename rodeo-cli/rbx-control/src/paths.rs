use std::path::PathBuf;

/// Platform-specific Roblox user logs directory.
/// macOS: ~/Library/Logs/Roblox
/// Windows: %LOCALAPPDATA%\Roblox\logs
pub fn roblox_logs_dir() -> Option<PathBuf> {
    #[cfg(target_os = "macos")]
    {
        dirs::home_dir().map(|h| h.join("Library/Logs/Roblox"))
    }
    #[cfg(target_os = "windows")]
    {
        dirs::data_local_dir().map(|d| d.join("Roblox/logs"))
    }
    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        None
    }
}

/// Microprofiler capture directory: roblox_logs_dir()/ProfilerCaptures
pub fn profiler_captures_dir() -> Option<PathBuf> {
    roblox_logs_dir().map(|d| d.join("ProfilerCaptures"))
}

/// Path to the StudioMCP binary, derived from the Studio application path.
/// macOS: RobloxStudio.app/Contents/MacOS/StudioMCP
/// Windows: adjacent to RobloxStudio.exe as StudioMCP.exe
pub fn studio_mcp_path() -> Option<PathBuf> {
    let studio = roblox_install::RobloxStudio::locate().ok()?;

    #[cfg(target_os = "macos")]
    {
        let app = studio
            .application_path()
            .ancestors()
            .find(|p| p.extension().is_some_and(|e| e == "app"))?;
        Some(app.join("Contents/MacOS/StudioMCP"))
    }

    #[cfg(target_os = "windows")]
    {
        Some(
            studio
                .application_path()
                .parent()?
                .join("StudioMCP.exe"),
        )
    }

    #[cfg(not(any(target_os = "macos", target_os = "windows")))]
    {
        None
    }
}
