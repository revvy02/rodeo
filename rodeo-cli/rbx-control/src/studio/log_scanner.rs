//! Log scanner — watches the Roblox logs dir for newly-created Studio log
//! files so we can pair each log file with the Studio process that owns it.
//!
//! Modeled on [`profile_scanner`][crate::profile_scanner]: a single
//! background task owns a filesystem watcher (`notify-debouncer-full`) and
//! serves requests from Studio launch sites.
//!
//! Today the scanner supports one operation:
//! - `claim_new_log(since)`: return the first `*_Studio_*_last.log` whose
//!   creation event fires at-or-after `since`. Blocks up to `timeout` for a
//!   future event if no matching log has been observed yet.
//!
//! This replaces the previous mtime-based `discover_studio_log()` polling,
//! which picked the wrong log file when multiple Studios had overlapping
//! lifetimes (closing a Studio updated its mtime, making it appear "most
//! recent" even though other Studios were actively writing).
//!
//! The long-lived watcher also sets up the natural hook-point for a future
//! live-tailing API (streaming deltas per-execution while the script runs,
//! rather than dumping at Done).

use std::path::PathBuf;
use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime};
use notify_debouncer_full::{new_debouncer, DebounceEventResult};
use tokio::sync::{mpsc, oneshot};

/// Start the log scanner background task. Returns a clonable handle callers
/// use to issue commands.
pub fn start() -> LogScannerHandle {
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<ScannerCommand>();

    tokio::spawn(async move {
        let scan_dir = match crate::paths::roblox_logs_dir() {
            Some(d) => d,
            None => {
                tracing::warn!("log scanner: could not determine Roblox logs dir");
                return;
            }
        };

        // Ensure the dir exists so the watcher can subscribe even on a fresh machine.
        let _ = std::fs::create_dir_all(&scan_dir);

        let (fs_tx, mut fs_rx) = mpsc::unbounded_channel::<PathBuf>();
        let _debouncer = {
            let tx = fs_tx.clone();
            let mut debouncer = match new_debouncer(
                Duration::from_millis(200),
                None,
                move |result: DebounceEventResult| {
                    if let Ok(events) = result {
                        for event in events {
                            for path in event.paths.iter() {
                                let _ = tx.send(path.clone());
                            }
                        }
                    }
                },
            ) {
                Ok(d) => d,
                Err(e) => {
                    tracing::warn!("log scanner: failed to create watcher: {e}");
                    return;
                }
            };
            if let Err(e) = debouncer.watch(&scan_dir, notify::RecursiveMode::NonRecursive) {
                tracing::warn!("log scanner: failed to watch: {e}");
                return;
            }
            debouncer
        };

        // Paths we've already emitted as "new" — suppresses repeat events on
        // the same file (appends fire events too).
        let mut observed: Vec<(PathBuf, SystemTime)> = Vec::new();
        // Outstanding `claim_new_log` requests whose `since` hasn't yet been
        // matched by an observed creation. Resolved on the next matching event.
        let mut pending: Vec<(SystemTime, oneshot::Sender<Option<PathBuf>>)> = Vec::new();

        let mut reap = tokio::time::interval(Duration::from_secs(10));
        reap.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);

        loop {
            tokio::select! {
                path = fs_rx.recv() => {
                    let Some(path) = path else { break };
                    let name = match path.file_name().and_then(|n| n.to_str()) {
                        Some(n) => n,
                        None => continue,
                    };
                    if !name.contains("_Studio_") || !name.ends_with("_last.log") {
                        continue;
                    }
                    if observed.iter().any(|(p, _)| p == &path) {
                        continue;
                    }
                    let now = SystemTime::now();
                    tracing::debug!(path = %path.display(), "log scanner: observed new log");
                    observed.push((path.clone(), now));

                    // Fulfill any pending claim whose `since` is at-or-before now.
                    let mut i = 0;
                    while i < pending.len() {
                        if pending[i].0 <= now {
                            let (_, reply) = pending.swap_remove(i);
                            let _ = reply.send(Some(path.clone()));
                        } else {
                            i += 1;
                        }
                    }
                }
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(ScannerCommand::ClaimNewLog { since, reply }) => {
                            // Fast path: we've already observed a matching log.
                            let hit = observed.iter()
                                .find(|(_, ts)| *ts >= since)
                                .map(|(p, _)| p.clone());
                            if let Some(p) = hit {
                                let _ = reply.send(Some(p));
                            } else {
                                pending.push((since, reply));
                            }
                        }
                        None => break,
                    }
                }
                _ = reap.tick() => {
                    // Drop claims whose callers have dropped their receiver
                    // (timed out on their side). Also prunes ancient observations
                    // to keep the vector bounded.
                    pending.retain(|(_, reply)| !reply.is_closed());
                    if observed.len() > 1024 {
                        observed.drain(..observed.len() - 512);
                    }
                }
            }
        }
    });

    LogScannerHandle { cmd_tx }
}

enum ScannerCommand {
    ClaimNewLog {
        since: SystemTime,
        reply: oneshot::Sender<Option<PathBuf>>,
    },
}

/// Clonable handle used by Studio launch sites to pair a Studio with its log.
#[derive(Clone)]
pub struct LogScannerHandle {
    cmd_tx: mpsc::UnboundedSender<ScannerCommand>,
}

impl LogScannerHandle {
    /// Return the first `*_Studio_*_last.log` whose creation event arrives at
    /// or after `since`. Waits up to `timeout` for a future event. Returns
    /// `None` on timeout or if the scanner has shut down.
    pub async fn claim_new_log(&self, since: SystemTime, timeout: Duration) -> Option<PathBuf> {
        let (reply_tx, reply_rx) = oneshot::channel();
        self.cmd_tx.send(ScannerCommand::ClaimNewLog { since, reply: reply_tx }).ok()?;
        tokio::time::timeout(timeout, reply_rx).await.ok()?.ok().flatten()
    }

    /// Spawn a background task that claims a log for a process launched at
    /// `launched_at` and writes it into `slot`. Single helper used by every
    /// Studio-class launch site (edit, MP-test server, MP-test client).
    pub fn pair(&self, launched_at: SystemTime, slot: ProcessLog) {
        let scanner = self.clone();
        tokio::spawn(async move {
            if let Some(path) = scanner.claim_new_log(launched_at, Duration::from_secs(10)).await {
                slot.set(path);
            }
        });
    }
}

/// Cheaply-cloneable per-process slot that a `LogScannerHandle::pair` task
/// writes the claimed log path into. Every Studio-class process owns one;
/// per-execution log capture reads it to find the right `*_Studio_*_last.log`
/// to byte-delta from.
#[derive(Clone, Default)]
pub struct ProcessLog(Arc<Mutex<Option<PathBuf>>>);

impl ProcessLog {
    pub fn new() -> Self { Self::default() }
    pub fn set(&self, path: PathBuf) {
        *self.0.lock().unwrap() = Some(path);
    }
    pub fn get(&self) -> Option<PathBuf> {
        self.0.lock().unwrap().clone()
    }
}
