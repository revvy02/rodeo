//! Profile dump scanner — watches ProfilerCaptures directory for .raw/.html dumps
//! that contain a matching `{label_prefix}:{run_id}` label, and sends them to the caller.
//! Uses `notify-debouncer-full` for deduplicated, stable file detection.

use std::collections::HashMap;
use std::path::PathBuf;
use notify_debouncer_full::{new_debouncer, DebounceEventResult};
use tokio::sync::mpsc;

/// A matched profile dump ready to be sent.
#[derive(Debug, Clone)]
pub struct ProfileDump {
    pub execution_id: String,
    pub filename: String,
    pub data: Vec<u8>,
}

/// Get the default ProfilerCaptures directory.
fn profiler_captures_dir() -> Option<PathBuf> {
    crate::paths::profiler_captures_dir()
}

/// Check if a file's binary content contains the label for `execution_id`.
fn file_contains_label(data: &[u8], execution_id: &str, label_prefix: &str) -> bool {
    let needle = format!("{label_prefix}:{execution_id}");
    data.windows(needle.len()).any(|w| w == needle.as_bytes())
}

/// Start the profile scanner background task.
///
/// `label_prefix` is the string stamped into dumps by the profiler that pairs
/// captures with a particular execution — callers choose their own prefix and
/// register runs by id. The watcher matches dumps whose binary content contains
/// `{label_prefix}:{execution_id}`; prefix-agnostic otherwise.
pub fn start(label_prefix: &str) -> ProfileScannerHandle {
    let label_prefix = label_prefix.to_string();
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded_channel::<ScannerCommand>();

    tokio::spawn(async move {
        let scan_dir = match profiler_captures_dir() {
            Some(d) => d,
            None => {
                tracing::warn!("could not determine ProfilerCaptures directory");
                return;
            }
        };

        // Ensure the dir exists so the watcher can subscribe. Roblox doesn't
        // create ProfilerCaptures until its first dump, so without this the
        // watch fails on a fresh machine ("path is neither a file nor a
        // directory"), the scanner task exits, and no dumps are ever captured.
        let _ = std::fs::create_dir_all(&scan_dir);

        let (fs_tx, mut fs_rx) = mpsc::unbounded_channel::<PathBuf>();
        let _debouncer = {
            let tx = fs_tx.clone();
            let mut debouncer = match new_debouncer(
                std::time::Duration::from_millis(500),
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
                    tracing::warn!("failed to create file watcher: {e}");
                    return;
                }
            };
            if let Err(e) = debouncer.watch(&scan_dir, notify::RecursiveMode::NonRecursive) {
                tracing::warn!("failed to watch ProfilerCaptures: {e}");
                return;
            }
            debouncer
        };

        let mut active_runs: HashMap<String, mpsc::UnboundedSender<ProfileDump>> = HashMap::new();

        loop {
            tokio::select! {
                path = fs_rx.recv() => {
                    let path = match path {
                        Some(p) => p,
                        None => break,
                    };
                    if active_runs.is_empty() { continue; }
                    let ext = path.extension().and_then(|e| e.to_str()).unwrap_or("");
                    if ext != "raw" && ext != "html" { continue; }
                    let filename = match path.file_name().and_then(|n| n.to_str()) {
                        Some(n) => n.to_string(),
                        None => continue,
                    };
                    let data = match std::fs::read(&path) {
                        Ok(d) => d,
                        Err(_) => continue,
                    };
                    for (execution_id, tx) in &active_runs {
                        if file_contains_label(&data, execution_id, &label_prefix) {
                            tracing::info!(execution_id, filename, size = data.len(), "profile scanner: matched dump");
                            let _ = tx.send(ProfileDump {
                                execution_id: execution_id.clone(),
                                filename: filename.clone(),
                                data: data.clone(),
                            });
                        }
                    }
                }
                cmd = cmd_rx.recv() => {
                    match cmd {
                        Some(ScannerCommand::Register { execution_id, tx }) => {
                            tracing::debug!(execution_id, "profile scanner: registered run");
                            active_runs.insert(execution_id, tx);
                        }
                        Some(ScannerCommand::Unregister { execution_id }) => {
                            tracing::debug!(execution_id, "profile scanner: unregistered run");
                            active_runs.remove(&execution_id);
                        }
                        None => break,
                    }
                }
            }
        }
    });

    ProfileScannerHandle { cmd_tx }
}

enum ScannerCommand {
    Register {
        execution_id: String,
        tx: mpsc::UnboundedSender<ProfileDump>,
    },
    Unregister {
        execution_id: String,
    },
}

/// Handle for interacting with the profile scanner.
#[derive(Clone)]
pub struct ProfileScannerHandle {
    cmd_tx: mpsc::UnboundedSender<ScannerCommand>,
}

impl ProfileScannerHandle {
    /// Register a profiled run. Returns a receiver for matched dumps.
    pub fn register(&self, execution_id: String) -> mpsc::UnboundedReceiver<ProfileDump> {
        let (tx, rx) = mpsc::unbounded_channel();
        let _ = self.cmd_tx.send(ScannerCommand::Register { execution_id, tx });
        rx
    }

    /// Unregister a profiled run. Drops the sender, closing the receiver.
    pub fn unregister(&self, execution_id: &str) {
        let _ = self.cmd_tx.send(ScannerCommand::Unregister {
            execution_id: execution_id.to_string(),
        });
    }
}
