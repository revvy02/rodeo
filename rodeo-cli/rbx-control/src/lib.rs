//! Control plane for Roblox processes.
//!
//! Reusable, consumer-agnostic infrastructure for automating Roblox Studio
//! and Roblox Player. Modules split along process type:
//!
//! - [`studio`] — Studio-specific mechanics (launch-slot daemon, log
//!   scanner, StudioMCP JSON-RPC client).
//! - [`player`] — Roblox Player launch and process handle.
//! - [`fflags`], [`paths`], [`place`], [`profile_scanner`] — cross-cutting
//!   infrastructure shared by Studio and Player consumers.
//!
//! Nothing here depends on or names any particular consumer — callers
//! compose these pieces into their own orchestration.

pub mod fflags;
pub mod paths;
pub mod place;
pub mod player;
pub mod profile_scanner;
pub mod studio;

/// Is a process with this pid currently alive? Used by the stale-lock sweeps
/// ([`fflags::sweep_stale_leak`], [`studio::layout::sweep_stale_leak`]) to tell
/// a live patch from one leaked by a crashed/hard-killed run.
#[cfg(unix)]
pub fn pid_alive(pid: u32) -> bool {
    // kill(pid, 0) probes existence without signaling: 0 => alive; EPERM =>
    // exists but not ours (still alive); ESRCH => dead.
    let rc = unsafe { libc::kill(pid as libc::pid_t, 0) };
    rc == 0 || std::io::Error::last_os_error().raw_os_error() == Some(libc::EPERM)
}

#[cfg(windows)]
pub fn pid_alive(pid: u32) -> bool {
    // Feature-gated constant in windows-sys 0.59; hardcode the stable value
    // (matches launch-control's usage).
    const PROCESS_QUERY_LIMITED_INFORMATION: u32 = 0x1000;
    unsafe {
        let handle = windows_sys::Win32::System::Threading::OpenProcess(
            PROCESS_QUERY_LIMITED_INFORMATION,
            0,
            pid,
        );
        if handle.is_null() {
            return false;
        }
        windows_sys::Win32::Foundation::CloseHandle(handle);
        true
    }
}
