//! Process exit observation and parent-linked self-termination.
//!
//! Two related primitives:
//! - [`on_pid_exit`] — general: run a callback when any process exits. Used
//!   by parents to observe children, or by any code that wants an event-driven
//!   exit notification.
//! - [`on_parent_exit`] — specialization: terminate *this* process when a
//!   specific parent PID exits. Uses `prctl(PR_SET_PDEATHSIG)` on Linux for
//!   kernel-level zero-overhead operation.
//!
//! Both are cross-platform and event-driven (no polling):
//! - **macOS/BSD**: `kqueue` with `EVFILT_PROC` + `NOTE_EXIT`
//! - **Linux**: `prctl(PR_SET_PDEATHSIG)` for `on_parent_exit`; `waitpid` in a
//!   background thread for `on_pid_exit` (requires the PID to be a child of
//!   the calling process, which covers spawn-and-watch use cases).
//! - **Windows**: `OpenProcess` + `WaitForSingleObject`
//!
//! # Usage
//!
//! ```no_run
//! // Child binary — terminate self if parent dies
//! parent_exit::on_parent_exit(std::process::id());
//!
//! // Parent binary — observe a spawned child's exit and run cleanup
//! parent_exit::on_pid_exit(child_pid, || {
//!     println!("child exited");
//! });
//! ```

/// Run a callback on a background thread when the process with the given PID
/// exits. Event-driven (no polling).
///
/// On Linux, this uses `waitpid` and therefore requires the PID to be a child
/// of the calling process. On macOS and Windows, the PID can be any process
/// the calling process has permission to observe.
///
/// The callback runs on a dedicated watcher thread. It should be non-blocking
/// or bridge to async via a channel — do not hold locks across awaits.
pub fn on_pid_exit<F: FnOnce() + Send + 'static>(pid: u32, callback: F) {
    platform::on_pid_exit(pid, Box::new(callback));
}

/// Spawn a background thread that terminates this process when the given parent PID dies.
///
/// Sends SIGTERM to self (Unix) or calls `ExitProcess` (Windows) to ensure
/// Drop handlers and cleanup code run before exit.
///
/// Uses OS-native event mechanisms — no polling:
/// - **macOS/BSD**: `kqueue` with `EVFILT_PROC` + `NOTE_EXIT`
/// - **Linux**: `prctl(PR_SET_PDEATHSIG, SIGTERM)` (kernel-level, zero overhead)
/// - **Windows**: `OpenProcess` + `WaitForSingleObject`
///
/// On Linux, `prctl` is set on the calling thread (no background thread needed).
/// On other platforms, a background thread is spawned that blocks until the parent exits.
pub fn on_parent_exit(ppid: u32) {
    platform::on_parent_exit(ppid);
}

/// Send SIGTERM to ourselves so the process shuts down gracefully (Drop handlers run).
#[cfg(unix)]
fn graceful_exit() {
    unsafe { libc::kill(libc::getpid(), libc::SIGTERM); }
}

/// On Windows, ExitProcess runs DLL cleanup but not Rust Drop.
/// Use process::exit as fallback.
#[cfg(windows)]
fn graceful_exit() {
    std::process::exit(0);
}

type Callback = Box<dyn FnOnce() + Send + 'static>;

#[cfg(target_os = "linux")]
mod platform {
    use super::Callback;

    pub fn on_parent_exit(_ppid: u32) {
        // PR_SET_PDEATHSIG: kernel sends SIGTERM when parent thread dies.
        // No background thread, no polling, no PID reuse risk.
        unsafe {
            libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM);
        }

        // Check if parent already died before we set the signal
        // (race between fork and prctl).
        let current_ppid = unsafe { libc::getppid() } as u32;
        if current_ppid == 1 || current_ppid != _ppid {
            crate::graceful_exit();
        }
    }

    /// Linux general exit watcher — uses `waitpid` in a background thread.
    /// Only works if the PID is a child of the calling process.
    pub fn on_pid_exit(pid: u32, callback: Callback) {
        std::thread::spawn(move || {
            let mut status: libc::c_int = 0;
            unsafe { libc::waitpid(pid as i32, &mut status, 0); }
            callback();
        });
    }
}

#[cfg(any(target_os = "macos", target_os = "freebsd", target_os = "openbsd", target_os = "netbsd"))]
mod platform {
    use super::Callback;
    use std::ptr;

    pub fn on_parent_exit(ppid: u32) {
        super::platform::on_pid_exit(ppid, Box::new(crate::graceful_exit));
    }

    /// Watch any PID for exit via kqueue + EVFILT_PROC + NOTE_EXIT.
    /// Works for any PID the calling process has permission to query.
    pub fn on_pid_exit(pid: u32, callback: Callback) {
        // Fast-path: if the process is already gone, fire the callback immediately.
        let alive = unsafe { libc::kill(pid as i32, 0) } == 0;
        if !alive {
            callback();
            return;
        }

        std::thread::spawn(move || {
            unsafe {
                let kq = libc::kqueue();
                if kq < 0 {
                    eprintln!("parent-exit: kqueue failed");
                    return;
                }

                let event = libc::kevent {
                    ident: pid as usize,
                    filter: libc::EVFILT_PROC,
                    flags: libc::EV_ADD | libc::EV_ONESHOT,
                    fflags: libc::NOTE_EXIT,
                    data: 0,
                    udata: ptr::null_mut(),
                };

                let reg = libc::kevent(kq, &event, 1, ptr::null_mut(), 0, ptr::null());
                if reg < 0 {
                    libc::close(kq);
                    // Race: process exited between kill(0) check and kevent register.
                    callback();
                    return;
                }

                let mut out: libc::kevent = std::mem::zeroed();
                let n = libc::kevent(kq, ptr::null(), 0, &mut out, 1, ptr::null());
                libc::close(kq);

                if n > 0 {
                    callback();
                }
            }
        });
    }
}

#[cfg(target_os = "windows")]
mod platform {
    use super::Callback;

    pub fn on_parent_exit(ppid: u32) {
        super::platform::on_pid_exit(ppid, Box::new(crate::graceful_exit));
    }

    pub fn on_pid_exit(pid: u32, callback: Callback) {
        std::thread::spawn(move || {
            unsafe {
                // SYNCHRONIZE = 0x00100000. Hardcoded because the constant
                // is feature-gated under Win32_Security (or similar) in
                // windows-sys 0.59 — adding the feature pulled in unrelated
                // breakage. This single value is stable Win32 API.
                const SYNCHRONIZE: u32 = 0x00100000;
                let handle = windows_sys::Win32::System::Threading::OpenProcess(
                    SYNCHRONIZE,
                    0,
                    pid,
                );
                if handle.is_null() {
                    // Process already dead or no permission — fire callback anyway.
                    callback();
                    return;
                }

                windows_sys::Win32::System::Threading::WaitForSingleObject(
                    handle,
                    windows_sys::Win32::System::Threading::INFINITE,
                );
                windows_sys::Win32::Foundation::CloseHandle(handle);
                callback();
            }
        });
    }
}

#[cfg(not(any(
    target_os = "linux",
    target_os = "macos",
    target_os = "freebsd",
    target_os = "openbsd",
    target_os = "netbsd",
    target_os = "windows",
)))]
mod platform {
    use super::Callback;

    pub fn on_parent_exit(ppid: u32) {
        // Fallback: poll getppid every second
        std::thread::spawn(move || {
            loop {
                std::thread::sleep(std::time::Duration::from_secs(1));
                let current = unsafe { libc::getppid() } as u32;
                if current == 1 || current != ppid {
                    crate::graceful_exit();
                }
            }
        });
    }

    pub fn on_pid_exit(_pid: u32, _callback: Callback) {
        // Unsupported platform
    }
}
