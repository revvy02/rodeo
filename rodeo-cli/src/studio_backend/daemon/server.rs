//! Daemon supervisor loop. Listens on the Unix socket, handles client requests,
//! and gates Studio launches via the slot queue.

use anyhow::Result;
use std::collections::{HashMap, VecDeque};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use super::{DaemonRunOpts, Request, Response};

const IDLE_TIMEOUT: Duration = Duration::from_secs(5);

// ---------------------------------------------------------------------------
// Daemon State
// ---------------------------------------------------------------------------

struct ActiveSlot {
    id: String,
    pid: u32,
    client_id: u64,
}

struct PendingLaunch {
    request_id: u64,
    client_id: u64,
}

struct DaemonState {
    max_slots: usize,
    active: Vec<ActiveSlot>,
    launch_queue: VecDeque<PendingLaunch>,
    /// True while a backend is in the process of launching + logging in.
    /// Only one launch at a time to avoid auth token races.
    launch_in_progress: bool,
    serialize_launches: bool,
    next_client_id: u64,
    clients: HashMap<u64, UnixStream>,
}

impl DaemonState {
    fn new(max_slots: usize, serialize_launches: bool) -> Self {
        Self {
            max_slots,
            active: Vec::new(),
            launch_queue: VecDeque::new(),
            launch_in_progress: false,
            serialize_launches,
            next_client_id: 1,
            clients: HashMap::new(),
        }
    }

    fn can_grant_launch(&self) -> bool {
        self.active.len() < self.max_slots && (!self.serialize_launches || !self.launch_in_progress)
    }
}

// ---------------------------------------------------------------------------
// Daemon Main
// ---------------------------------------------------------------------------

pub fn main(opts: DaemonRunOpts) -> Result<()> {
    let DaemonRunOpts { paths, max_slots, serialize_launches } = opts;
    let sock_path = paths.socket();
    let pid_file = paths.pid();

    if let Some(parent) = sock_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    // Check if another daemon is already running
    if std::os::unix::net::UnixStream::connect(&sock_path).is_ok() {
        // Another daemon is alive — exit silently
        return Ok(());
    }

    // Remove stale socket (from a crashed daemon)
    let _ = std::fs::remove_file(&sock_path);

    // Write PID file
    std::fs::write(&pid_file, std::process::id().to_string())?;

    let listener = match UnixListener::bind(&sock_path) {
        Ok(l) => l,
        Err(_) => {
            // Another daemon won the race — exit silently
            return Ok(());
        }
    };
    listener.set_nonblocking(true)?;

    eprintln!("studio-daemon: listening (max {max_slots} studios)");

    let state = Arc::new(Mutex::new(DaemonState::new(max_slots, serialize_launches)));
    let mut last_activity = Instant::now();

    loop {
        match listener.accept() {
            Ok((stream, _)) => {
                // Accepted sockets inherit non-blocking from listener — set back to blocking
                let _ = stream.set_nonblocking(false);
                last_activity = Instant::now();
                let client_id = {
                    let mut guard = state.lock().unwrap();
                    let id = guard.next_client_id;
                    guard.next_client_id += 1;
                    id
                };
                let state_clone = Arc::clone(&state);
                std::thread::spawn(move || {
                    handle_client(stream, client_id, state_clone);
                });
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {}
            Err(e) => {
                eprintln!("studio-daemon: accept error: {e}");
            }
        }

        // Idle timeout
        {
            let guard = state.lock().unwrap();
            if guard.active.is_empty()
                && guard.launch_queue.is_empty()
                && guard.clients.is_empty()
            {
                if last_activity.elapsed() > IDLE_TIMEOUT {
                    eprintln!("studio-daemon: idle timeout, exiting");
                    break;
                }
            } else {
                last_activity = Instant::now();
            }
        }

        std::thread::sleep(Duration::from_millis(50));
    }

    let _ = std::fs::remove_file(&sock_path);
    let _ = std::fs::remove_file(&pid_file);
    Ok(())
}

// ---------------------------------------------------------------------------
// Client handler
// ---------------------------------------------------------------------------

fn handle_client(stream: UnixStream, client_id: u64, state: Arc<Mutex<DaemonState>>) {
    eprintln!("studio-daemon: client {client_id} connected");
    let reader_stream = match stream.try_clone() {
        Ok(s) => s,
        Err(e) => {
            eprintln!("studio-daemon: client {client_id} clone failed: {e}");
            return;
        }
    };

    {
        let writer = match stream.try_clone() {
            Ok(s) => s,
            Err(e) => {
                eprintln!("studio-daemon: client {client_id} writer clone failed: {e}");
                return;
            }
        };
        state.lock().unwrap().clients.insert(client_id, writer);
    }

    // Drop the original stream — clones have their own fds
    drop(stream);

    let reader = BufReader::new(reader_stream);
    eprintln!("studio-daemon: client {client_id} reading lines...");
    for line in reader.lines() {
        let line = match line {
            Ok(l) => {
                eprintln!("studio-daemon: client {client_id} got line: {}", &l[..l.len().min(80)]);
                l
            }
            Err(e) => {
                eprintln!("studio-daemon: client {client_id} read error: {e}");
                break;
            }
        };

        let request: Request = match serde_json::from_str(&line) {
            Ok(r) => r,
            Err(e) => {
                eprintln!("studio-daemon: bad request: {e}");
                continue;
            }
        };

        match request {
            Request::AcquireSlot { id } => {
                // Atomic check-and-grant: hold the lock across both to avoid TOCTOU race
                let granted = {
                    let mut guard = state.lock().unwrap();
                    if guard.can_grant_launch() {
                        guard.launch_in_progress = true;
                        let slot_id = uuid::Uuid::new_v4().to_string();
                        guard.active.push(ActiveSlot {
                            id: slot_id.clone(),
                            pid: 0,
                            client_id,
                        });
                        eprintln!(
                            "studio-daemon: granted slot {slot_id} (active: {}, max: {})",
                            guard.active.len(),
                            guard.max_slots,
                        );
                        Some(slot_id)
                    } else {
                        guard.launch_queue.push_back(PendingLaunch {
                            request_id: id,
                            client_id,
                        });
                        eprintln!(
                            "studio-daemon: queued (active: {}, max: {}, launching: {})",
                            guard.active.len(),
                            guard.max_slots,
                            guard.launch_in_progress
                        );
                        None
                    }
                };
                if let Some(slot_id) = granted {
                    send_response(client_id, &state, Response {
                        id,
                        result: Some(serde_json::json!({ "slot_id": slot_id })),
                        error: None,
                    });
                }
                // If not granted, client blocks — response sent when dequeued
            }
            Request::LaunchComplete { id, slot_id, pid } => {
                let mut guard = state.lock().unwrap();
                // Record the PID and mark launch complete
                if let Some(slot) = guard.active.iter_mut().find(|s| s.id == slot_id) {
                    slot.pid = pid;
                }
                guard.launch_in_progress = false;
                eprintln!("studio-daemon: launch complete, pid {pid} (active: {})", guard.active.len());
                drop(guard);

                send_response(client_id, &state, Response {
                    id,
                    result: Some(serde_json::json!({ "ok": true })),
                    error: None,
                });

                // Dequeue next
                try_dequeue(&state);
            }
            Request::ReleaseSlot { id, slot_id } => {
                let mut guard = state.lock().unwrap();
                if let Some(pos) = guard.active.iter().position(|s| s.id == slot_id) {
                    let slot = guard.active.remove(pos);
                    if slot.pid > 0 {
                        let _ = kill_process(slot.pid);
                    }
                    eprintln!("studio-daemon: released slot (active: {})", guard.active.len());
                }
                drop(guard);

                send_response(client_id, &state, Response {
                    id,
                    result: Some(serde_json::json!({ "ok": true })),
                    error: None,
                });

                try_dequeue(&state);
            }
            Request::Status { id } => {
                let guard = state.lock().unwrap();
                let result = serde_json::json!({
                    "active": guard.active.len(),
                    "max": guard.max_slots,
                    "queued": guard.launch_queue.len(),
                    "launching": guard.launch_in_progress,
                });
                drop(guard);

                send_response(client_id, &state, Response {
                    id,
                    result: Some(result),
                    error: None,
                });
            }
        }
    }

    // Client disconnected — cleanup
    cleanup_client(client_id, &state);
}

/// Try to dequeue and grant the next pending request (atomic check-and-grant).
fn try_dequeue(state: &Arc<Mutex<DaemonState>>) {
    let granted = {
        let mut guard = state.lock().unwrap();
        if guard.can_grant_launch() {
            if let Some(pending) = guard.launch_queue.pop_front() {
                guard.launch_in_progress = true;
                let slot_id = uuid::Uuid::new_v4().to_string();
                guard.active.push(ActiveSlot {
                    id: slot_id.clone(),
                    pid: 0,
                    client_id: pending.client_id,
                });
                eprintln!(
                    "studio-daemon: dequeued slot {slot_id} (active: {}, max: {})",
                    guard.active.len(),
                    guard.max_slots,
                );
                Some((pending.request_id, pending.client_id, slot_id))
            } else {
                None
            }
        } else {
            None
        }
    };

    if let Some((request_id, client_id, slot_id)) = granted {
        send_response(client_id, state, Response {
            id: request_id,
            result: Some(serde_json::json!({ "slot_id": slot_id })),
            error: None,
        });
    }
}

fn cleanup_client(client_id: u64, state: &Arc<Mutex<DaemonState>>) {
    let mut guard = state.lock().unwrap();
    guard.clients.remove(&client_id);

    let pids: Vec<u32> = guard
        .active
        .iter()
        .filter(|s| s.client_id == client_id && s.pid > 0)
        .map(|s| s.pid)
        .collect();

    let had_launching = guard.active.iter().any(|s| s.client_id == client_id && s.pid == 0);
    guard.active.retain(|s| s.client_id != client_id);
    guard.launch_queue.retain(|r| r.client_id != client_id);

    // If this client was mid-launch, clear the flag
    if had_launching && guard.launch_in_progress {
        guard.launch_in_progress = false;
    }

    let remaining = guard.active.len();
    drop(guard);

    for pid in pids {
        let _ = kill_process(pid);
    }

    eprintln!("studio-daemon: client {client_id} disconnected (active: {remaining})");
    try_dequeue(state);
}

fn send_response(client_id: u64, state: &Arc<Mutex<DaemonState>>, response: Response) {
    let mut guard = state.lock().unwrap();
    if let Some(stream) = guard.clients.get_mut(&client_id) {
        let mut msg = serde_json::to_string(&response).unwrap();
        msg.push('\n');
        let _ = stream.write_all(msg.as_bytes());
        let _ = stream.flush();
    }
}

fn kill_process(pid: u32) -> bool {
    unsafe { libc::kill(pid as i32, libc::SIGTERM) == 0 }
}
