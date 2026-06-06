use anyhow::{Context, Result};
use rodeo_client::RodeoClient;
use crate::util::config;
use crate::master::BackendState;
use crate::studio_backend::http::handle_connection as handle_studio_connection;
use std::net::SocketAddr;
use std::process::Stdio;
use std::sync::Arc;
use tokio::net::TcpListener;
use tokio::sync::Mutex;
use process_wrap::tokio::{CommandWrap, ChildWrapper};
#[cfg(unix)]
use process_wrap::tokio::ProcessGroup;
#[cfg(windows)]
use process_wrap::tokio::JobObject;

/// Which role(s) this serve instance runs.
pub enum ServeMode {
    /// Master + studio backend (default)
    Combined,
    /// Master only — accepts backends + CLI clients
    Master,
    /// Studio backend only — connects outbound to master
    Studio { master_host: String, master_port: u16 },
}

/// Ensure MCP Server is enabled in Studio's AI Assistant settings for all users.
#[cfg(any(target_os = "macos", target_os = "windows"))]
pub fn ensure_mcp_enabled() {
    let _studio = match roblox_install::RobloxStudio::locate() {
        Ok(s) => s,
        Err(_) => return,
    };

    #[cfg(target_os = "macos")]
    let assistant_dir = {
        let home = match std::env::var("HOME") {
            Ok(h) => std::path::PathBuf::from(h),
            Err(_) => return,
        };
        home.join("Library").join("Roblox").join("AssistantSettings")
    };

    #[cfg(target_os = "windows")]
    let assistant_dir = {
        let roblox_dir = _studio.application_path()
            .ancestors()
            .find(|p| p.file_name().map_or(false, |n| n == "Roblox"))
            .map(|p| p.to_path_buf());
        match roblox_dir {
            Some(dir) => dir.join("AssistantSettings"),
            None => return,
        }
    };

    let entries = match std::fs::read_dir(&assistant_dir) {
        Ok(e) => e,
        Err(_) => return,
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        let Ok(content) = std::fs::read_to_string(&path) else {
            continue;
        };
        let Ok(mut val) = serde_json::from_str::<serde_json::Value>(&content) else {
            continue;
        };
        if val.get("mcp-server").and_then(|m| m.get("enabled")).and_then(|e| e.as_bool()) == Some(true) {
            continue;
        }
        if let Some(obj) = val.as_object_mut() {
            obj.insert("mcp-server".into(), serde_json::json!({"enabled": true}));
            let _ = std::fs::write(&path, serde_json::to_string_pretty(&val).unwrap_or_default());
        }
    }
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
pub fn ensure_mcp_enabled() {}

// ---------------------------------------------------------------------------
// Role entry points (used by internal subcommands and public serve flags)
// ---------------------------------------------------------------------------

/// Run the master server. Blocks until the process exits.
///
/// `master_id` is the bootstrap UUID assigned by `util::log_capture::init`
/// at master startup; it's advertised to backends via `RegisterResponse` so
/// distributed logs can be correlated across hosts.
pub async fn run_master(port: u16, master_id: String) -> Result<()> {
    let state = Arc::new(Mutex::new(crate::master::MasterState::new(master_id)));

    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    let router = crate::master::grpc::build_router(state.clone());

    tracing::info!("Master serving on port {port}");

    if let Err(e) = connectrpc::Server::new(router).serve(addr).await {
        tracing::error!("master server error: {e}");
    }

    Ok(())
}

/// Run a studio backend. Blocks until the process exits.
pub async fn run_studio_backend(port: u16, master_host: &str, master_port: u16) -> Result<()> {
    ensure_mcp_enabled();

    // Sweep stale rodeo plugin files left behind by prior backend processes
    // that died ungracefully (SIGKILL / crash / OOM / etc — anything that
    // skipped Drop), then take an fd-lock for our own port. The kernel
    // releases the lock when this process terminates for any reason, which
    // is what makes the next backend's sweep able to detect "owner is
    // dead." See studio_backend::plugin_lock for the full rationale.
    crate::studio_backend::plugin_lock::sweep_stale_plugins();
    crate::studio_backend::plugin_lock::acquire_lock(port)
        .context("failed to acquire studio-backend plugin lock")?;

    let state = Arc::new(Mutex::new(BackendState::new()));
    state.lock().await.port = port;

    {
        let scanner = rbx_control::profile_scanner::start("rodeo");
        state.lock().await.profile_scanner = Some(scanner);
    }

    {
        let log_scanner = rbx_control::studio::log_scanner::start();
        state.lock().await.log_scanner = Some(log_scanner);
    }

    tokio::spawn(crate::master::run_reconciliation(state.clone()));

    let addr: SocketAddr = ([127, 0, 0, 1], port).into();
    let listener = TcpListener::bind(&addr)
        .await
        .context(format!("failed to bind to {addr}"))?;

    let accept_state = state.clone();
    tokio::spawn(async move {
        loop {
            match listener.accept().await {
                Ok((stream, _addr)) => {
                    let conn_state = accept_state.clone();
                    tokio::spawn(handle_studio_connection(stream, conn_state));
                }
                Err(e) => {
                    tracing::error!("Accept error: {e}");
                }
            }
        }
    });

    tracing::info!("Studio backend on port {port}, connecting to master at {master_host}:{master_port}");

    #[cfg(unix)]
    let mut sigterm = tokio::signal::unix::signal(
        tokio::signal::unix::SignalKind::terminate(),
    ).expect("failed to register SIGTERM handler");

    let master_fut = async {
        match crate::studio_backend::backend::connect_to_master(master_host, master_port, Some(port)).await {
            Ok((client, backend_id, master_id, bidi)) => {
                state.lock().await.master_id = master_id;
                crate::studio_backend::backend::run_master_loop(client, backend_id, bidi, state.clone()).await;
            }
            Err(e) => {
                tracing::error!("studio backend failed to connect to master: {e}");
            }
        }
    };

    #[cfg(unix)]
    tokio::select! {
        _ = master_fut => {}
        _ = sigterm.recv() => {
            tracing::info!("studio backend shutting down...");
            // Cancel all spawned tasks (launch, monitor, etc.)
            state.lock().await.shutdown_token.cancel();
        }
    }
    #[cfg(not(unix))]
    master_fut.await;

    // Explicitly clean up all Studio instances. Studios launched with
    // `detached: true` survive parent exit — skip kill for those and let
    // their Drop impl restore fflag/layout state without touching the
    // process.
    {
        let mut guard = state.lock().await;
        let count = guard.studio_instances.len();
        tracing::info!("cleaning up {count} studio instance(s)...");
        for (id, inst) in guard.studio_instances.drain() {
            if let Some(studio) = inst.studio {
                if studio.detached() {
                    tracing::info!(studio_id = id.as_str(), "studio is detached, skipping kill (process will survive)");
                    // Arc drop runs rodeo::Studio::Drop → rbx_control::Studio::Drop,
                    // both respect `detached` and only restore fflags/layout.
                    continue;
                }
                tracing::info!(studio_id = id.as_str(), "killing Studio");
                studio.kill();
            }
        }
    }

    Ok(())
}

// ---------------------------------------------------------------------------
// Combined serve: spawns master + backends as child processes
// ---------------------------------------------------------------------------

/// Handle returned by `start_full_serve` for lifecycle management.
pub struct ServeHandle {
    pub shutdown_rx: tokio::sync::mpsc::Receiver<()>,
    children: Vec<Box<dyn ChildWrapper>>,
}

impl ServeHandle {
    pub async fn wait_for_shutdown(mut self) {
        self.shutdown_rx.recv().await;
        tracing::info!("Shutting down...");
        self.kill_children().await;
    }

    pub async fn kill_children(&mut self) {
        // Send SIGTERM to each process group so children can clean up (e.g. kill Studio)
        #[cfg(unix)]
        for child in &self.children {
            let _ = child.signal(libc::SIGTERM);
        }
        #[cfg(not(unix))]
        for child in &mut self.children {
            let _ = child.start_kill();
        }
        for child in &mut self.children {
            let _ = child.wait().await;
        }
    }
}

impl Drop for ServeHandle {
    fn drop(&mut self) {
        #[cfg(unix)]
        for child in &self.children {
            let _ = child.signal(libc::SIGTERM);
        }
        #[cfg(not(unix))]
        for child in &mut self.children {
            let _ = child.start_kill();
        }
    }
}

fn spawn_in_group(exe: &std::path::Path, args: &[&str]) -> Result<Box<dyn ChildWrapper>> {
    let mut wrap = CommandWrap::with_new(exe, |cmd| {
        cmd.args(args)
            .stdin(Stdio::null())
            .stderr(Stdio::inherit());
    });
    // Put each child in its own kill group so termination cascades to
    // grandchildren (e.g. Studio): a Unix process group, or a Windows job
    // object (which kills the whole tree when the job handle is closed).
    #[cfg(unix)]
    wrap.wrap(ProcessGroup::leader());
    #[cfg(windows)]
    wrap.wrap(JobObject);
    let child = wrap
        .spawn()
        .context("failed to spawn child process")?;
    Ok(child)
}

/// Spawn master + studio backend as child processes.
/// Each child is in its own process group so kill propagates to grandchildren (e.g. Studio).
/// Waits for the studio backend to register before returning.
pub async fn start_full_serve(port: u16) -> Result<ServeHandle> {
    let exe = std::env::current_exe().context("cannot find own binary")?;
    let mut children: Vec<Box<dyn ChildWrapper>> = Vec::new();
    let ppid = std::process::id().to_string();

    // Spawn master
    children.push(spawn_in_group(&exe, &["__master", "--port", &port.to_string(), "--ppid", &ppid])?);

    // Wait for master to be healthy
    let rc = RodeoClient::connect("localhost", port)?;
    while !rc.is_healthy().await {
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }

    // Spawn studio backend
    let studio_port = port + 1;
    let studio_port_str = studio_port.to_string();
    let port_str = port.to_string();
    children.push(spawn_in_group(&exe, &["__studio-backend", "--port", &studio_port_str, "--master-host", "localhost", "--master-port", &port_str, "--ppid", &ppid])?);

    // Wait for the studio backend to register
    loop {
        let backends = rc.list_backends(None).await.unwrap_or_default();
        if backends.iter().any(|b| b.kind == "studio") { break; }
        tokio::time::sleep(std::time::Duration::from_millis(100)).await;
    }

    tracing::info!("Serving on port {port}");

    // Signal handler
    let (shutdown_tx, shutdown_rx) = tokio::sync::mpsc::channel::<()>(1);
    tokio::spawn(async move {
        #[cfg(unix)]
        {
            let mut sigterm = tokio::signal::unix::signal(
                tokio::signal::unix::SignalKind::terminate(),
            ).expect("failed to register SIGTERM handler");
            tokio::select! {
                _ = tokio::signal::ctrl_c() => {}
                _ = sigterm.recv() => {}
            }
        }
        #[cfg(not(unix))]
        {
            let _ = tokio::signal::ctrl_c().await;
        }
        let _ = shutdown_tx.try_send(());
    });

    Ok(ServeHandle { shutdown_rx, children })
}

// ---------------------------------------------------------------------------
// Public serve command entry point
// ---------------------------------------------------------------------------

pub async fn main(
    port: Option<u16>,
    mode: ServeMode,
) -> Result<()> {
    match mode {
        ServeMode::Combined | ServeMode::Master => {
            let port = port.unwrap_or(config::SERVE_PORT);
            let handle = start_full_serve(port).await?;
            handle.wait_for_shutdown().await;
        }
        ServeMode::Studio { master_host, master_port } => {
            let local_port = port.unwrap_or(config::SERVE_PORT);
            run_studio_backend(local_port, &master_host, master_port).await?;
        }
    }

    Ok(())
}
