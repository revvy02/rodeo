use anyhow::{bail, Context, Result};
use crate::cli::{FflagArgs, PlaceArgs, ServerArgs};
use crate::cli_run::{self, RunRequest};
use rodeo_client::RodeoClient;
use crate::commands::process_source::{self, ProcessedSource};
use crate::util::config;
use rodeo_proto as proto;

/// Create a connectrpc MasterService client for the given host/port.
fn master_client(host: &str, port: u16) -> Result<proto::MasterServiceClient<connectrpc::client::HttpClient>> {
    let url: http::Uri = format!("http://{host}:{port}")
        .parse()
        .context("invalid server URL")?;
    let http = connectrpc::client::HttpClient::plaintext();
    let config = connectrpc::client::ClientConfig::new(url);
    Ok(proto::MasterServiceClient::new(http, config))
}

/// All run command arguments
pub struct RunArgs {
    pub script: Option<String>,
    pub source: Option<String>,
    pub sourcemap: Option<String>,
    pub output: Option<String>,
    pub return_file: Option<String>,
    pub show_return: bool,
    pub target: Option<String>,
    pub no_warn: bool,
    pub no_error: bool,
    pub no_info: bool,
    pub no_print: bool,
    pub no_output: bool,
    pub cache_requires: bool,
    pub script_args: Vec<String>,
    pub server: ServerArgs,
    pub place: PlaceArgs,
    pub fflags: FflagArgs,
    pub verbose: bool,
}

struct ResolvedScript {
    script_path: Option<String>,
    script_content: String,
    instance_path: Option<String>,
}

struct RunConfig {
    script_content: String,
    script_path: Option<String>,
    output_file: Option<String>,
    return_file: Option<String>,
    show_return: bool,
    target: Option<String>,
    log_filter: proto::LogFilter,
    cache_requires: bool,
    script_args: Vec<String>,
    verbose: bool,
    instance_path: Option<String>,
    // Launch/server fields
    host: String,
    port: u16,
    place_target: Option<crate::studio_backend::PlaceTarget>,
    should_launch: bool,
    focus: bool,
    save: Option<String>,
    fflags: FflagArgs,
    detached: bool,
    no_hud: bool,
    // Targeting fields
    job: Option<String>,
    vm: Option<String>,
    // Profiling
    profile: Option<std::path::PathBuf>,
    // Log dump
    logs: Option<std::path::PathBuf>,
}

pub async fn main(mut args: RunArgs) -> Result<()> {
    let has_script = args.script.is_some() || args.source.is_some();
    let has_place = args.place.to_target().is_some();

    if has_place && !has_script {
        return persistent_mode(args).await;
    }

    let cfg = resolve_script(&mut args)?;
    let cfg = prepare_execution(args, cfg)?;
    let result = submit_and_run(cfg).await?;

    if result.exit_code != 0 {
        std::process::exit(result.exit_code);
    }
    Ok(())
}

/// Persistent mode: start serve + launch Studio, stay alive until Ctrl-C.
/// Other terminals can `rodeo run --port N --source "..."` against it.
async fn persistent_mode(args: RunArgs) -> Result<()> {
    let mut port = args.server.port;
    let place_target = args.place.to_target();

    if port == config::SERVE_PORT {
        port = config::ONCE_PORT;
    }

    if is_play_target(args.target.as_deref()) {
        // Play mode persistent: start serve, launch play processes via RPC
        let handle = super::serve::start_full_serve(port).await?;

        let target_str = args.target.as_deref().unwrap_or("play:server");
        let parsed = crate::shared::target::parse(target_str)?;

        let mut play_handles = launch_play_processes(
            &args.server.host,
            port,
            &parsed,
            place_target.as_ref(),
            !args.place.focus,
            &args.fflags,
            args.place.no_hud,
            args.place.profile.is_some(),
        ).await?;

        tracing::info!("Play mode running on port {port}. Press Ctrl-C to stop.");
        handle.wait_for_shutdown().await;
        play_handles.cleanup();
    } else {
        // Studio persistent mode
        let mut handle = super::serve::start_full_serve(port).await?;

        // `--logs` with no value resolves to `.rodeo/.temp/logs` — backend writes
        // per-session files `<logs_dir>/<session_guid>.log` so the dir is shared.
        let logs = args.place.logs.clone().map(|p| if p.is_empty() { ".rodeo/.temp/logs".to_string() } else { p });

        if let Some(target) = place_target {
            let req = build_launch_request(&target, !args.place.focus, args.place.save, args.fflags, args.place.detached, args.place.no_hud, args.place.profile.is_some(), logs, &args.server.host, port).await?;
            // Race Studio launch against ctrl-c. Bind the RodeoClient to a
            // local so its borrow outlives the tokio::select! future.
            let rc = RodeoClient::connect(&args.server.host, port)?;
            tokio::select! {
                r = rc.launch_studio_raw(req) => { r?; }
                _ = handle.shutdown_rx.recv() => {
                    tracing::info!("Shutting down...");
                    handle.kill_children().await;
                    return Ok(());
                }
            }
        }

        handle.wait_for_shutdown().await;
    }

    Ok(())
}

/// Resolve script source: read from file/stdin/--source, process, parse directives.
/// Call `rodeo __process_source` subprocess to bundle + shim + resolve the script.
fn call_process_source(
    script_path: Option<&str>,
    source: Option<&str>,
    sourcemap: Option<&str>,
) -> Result<ProcessedSource> {
    let exe = std::env::current_exe().context("cannot find own binary")?;
    let mut cmd = std::process::Command::new(&exe);
    cmd.arg("__process_source");

    if let Some(file) = script_path {
        cmd.arg(file);
    }
    if let Some(src) = source {
        cmd.args(["--source", src]);
    }
    if let Some(sm) = sourcemap {
        cmd.args(["--sourcemap", sm]);
    }

    let output = cmd.output().context("failed to run __process_source")?;
    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!("source processing failed: {}", stderr.trim());
    }

    serde_json::from_slice(&output.stdout)
        .context("failed to parse __process_source output")
}

fn resolve_script(args: &mut RunArgs) -> Result<ResolvedScript> {
    let script_path = match &args.script {
        Some(s) if s == "-" => {
            use std::io::Read;
            let mut buf = String::new();
            std::io::stdin()
                .read_to_string(&mut buf)
                .context("failed to read stdin")?;
            args.source = Some(buf);
            None
        }
        Some(s) => Some(s.clone()),
        None => None,
    };

    if script_path.is_none() && args.source.is_none() {
        bail!("no script source provided. Use a file path, '-' for stdin, or --source for inline execution");
    }

    let processed = call_process_source(
        script_path.as_deref(),
        args.source.as_deref(),
        args.sourcemap.as_deref(),
    )?;

    // Directive merging is done in the parent at main.rs entry before clap
    // even hands us the final RunArgs — by the time we get here, directive
    // flags are already represented in `args` via clap's normal parse path.

    Ok(ResolvedScript {
        script_path: processed.script_path,
        script_content: processed.script,
        instance_path: processed.instance_path,
    })
}

/// Build RunConfig: validate target, build log filter, assemble config.
fn prepare_execution(args: RunArgs, resolved: ResolvedScript) -> Result<RunConfig> {
    // Validate the target string if specified
    if let Some(ref t) = args.target {
        crate::shared::target::parse(t)?;
    }

    let log_filter = process_source::execution::build_log_filter(
        args.no_warn, args.no_error, args.no_info, args.no_print, args.no_output,
    );

    let host = args.server.host.clone();
    let mut port = args.server.port;
    let place_target = args.place.to_target();
    let _is_play = is_play_target(args.target.as_deref());
    let should_launch = place_target.is_some();
    if should_launch && port == config::SERVE_PORT {
        port = config::ONCE_PORT;
    }

    // Always generate a run_id for correlation
    let _run_id = uuid::Uuid::new_v4().to_string().split('-').next().unwrap().to_string();

    // Resolve --profile output dir. Flat — filenames carry the run_id /
    // execution_id + session_guid, so a single shared dir avoids per-run
    // subdir churn and keeps `ls` / grep scoped to one location.
    let profile = args.place.profile.as_ref().map(|p| {
        if p.is_empty() {
            std::path::PathBuf::from(".rodeo/.temp/profiles")
        } else {
            std::path::PathBuf::from(p)
        }
    });

    // Resolve --logs output dir. Flat for the same reason as --profile.
    let logs = args.place.logs.as_ref().map(|p| {
        if p.is_empty() {
            std::path::PathBuf::from(".rodeo/.temp/logs")
        } else {
            std::path::PathBuf::from(p)
        }
    });

    let fflags = args.fflags;

    Ok(RunConfig {
        script_content: resolved.script_content,
        target: args.target,
        log_filter,
        cache_requires: args.cache_requires,
        script_args: args.script_args,
        verbose: args.verbose,
        instance_path: resolved.instance_path,
        script_path: resolved.script_path.or(args.source),
        output_file: args.output,
        return_file: args.return_file,
        show_return: args.show_return,
        host,
        port,
        place_target,
        should_launch,
        focus: args.place.focus,
        save: args.place.save,
        fflags,
        detached: args.place.detached,
        no_hud: args.place.no_hud,
        job: args.place.job,
        vm: args.place.vm,
        profile,
        logs,
    })
}

/// Connect to (or launch) the server and execute the script.
async fn submit_and_run(cfg: RunConfig) -> Result<rodeo_client::RunResult> {
    let mut serve_handle: Option<super::serve::ServeHandle> = None;
    let mut _play_handles: Option<PlayHandles> = None;
    let mut launched_studio_id: Option<String> = None;

    if is_play_target(cfg.target.as_deref()) {
        // Play mode: ensure the session + requested client(s) exist.
        // NOTE: we do NOT gate on cfg.should_launch — `should_launch` is only
        // true when --place was provided, but `rodeo run --target
        // play:client:N -s 'code'` against an already-running play server
        // must still spawn the client.
        if !RodeoClient::connect(&cfg.host, cfg.port)?.is_healthy().await {
            let handle = super::serve::start_full_serve(cfg.port).await?;
            serve_handle = Some(handle);
        }

        let target_str = cfg.target.as_deref().unwrap_or("play:server");
        let parsed = crate::shared::target::parse(target_str)?;

        _play_handles = Some(launch_play_processes(
            &cfg.host,
            cfg.port,
            &parsed,
            cfg.place_target.as_ref(),
            !cfg.focus,
            &cfg.fflags,
            cfg.no_hud,
            cfg.profile.is_some(),
        )
        .await?);
    } else if cfg.place_target.is_some() && !RodeoClient::connect(&cfg.host, cfg.port)?.is_healthy().await {
        // Studio launch (edit/run/test modes)
        let handle = super::serve::start_full_serve(cfg.port).await?;
        serve_handle = Some(handle);

        if let Some(ref target) = cfg.place_target {
            let req = build_launch_request(target, !cfg.focus, cfg.save.clone(), cfg.fflags.clone(), cfg.detached, cfg.no_hud, cfg.profile.is_some(), cfg.logs.as_ref().map(|p| p.to_string_lossy().into_owned()), &cfg.host, cfg.port).await?;
            // Race launch against shutdown (ctrl-c / SIGTERM)
            if let Some(ref mut handle) = serve_handle {
                let rc = RodeoClient::connect(&cfg.host, cfg.port)?;
                tokio::select! {
                    r = rc.launch_studio_raw(req) => {
                        launched_studio_id = Some(r?.1);
                    }
                    _ = handle.shutdown_rx.recv() => {
                        tracing::info!("Shutting down...");
                        if let Some(mut h) = serve_handle.take() {
                            h.kill_children().await;
                        }
                        return Ok(rodeo_client::RunResult { exit_code: 130, ..Default::default() });
                    }
                }
            } else {
                let (_, studio_id) = RodeoClient::connect(&cfg.host, cfg.port)?.launch_studio_raw(req).await?;
                launched_studio_id = Some(studio_id);
            }
        }
    }

    if cfg.should_launch {
        if !RodeoClient::connect(&cfg.host, cfg.port)?.wait_for_healthy().await {
            bail!("no rodeo server found at {}:{}", cfg.host, cfg.port);
        }
    } else {
        // Brief retry in case server is still starting up
        let mut found = false;
        for _ in 0..6 {
            if RodeoClient::connect(&cfg.host, cfg.port)?.is_healthy().await {
                found = true;
                break;
            }
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
        }
        if !found {
            bail!("no rodeo server found at {}:{}. Run 'rodeo serve --port {}' first.", cfg.host, cfg.port, cfg.port);
        }
    }

    let is_profiling = cfg.profile.is_some();
    let is_logging = cfg.logs.is_some();
    let request = RunRequest {
        script: cfg.script_content,
        target: cfg.target.unwrap_or_default(),
        vm_id: cfg.vm,
        job: cfg.job,
        log_filter: cfg.log_filter,
        cache_requires: cfg.cache_requires,
        script_args: cfg.script_args,
        return_file: cfg.return_file,
        show_return: cfg.show_return,
        output_file: cfg.output_file,
        verbose: cfg.verbose,
        instance_path: cfg.instance_path,
        script_path: cfg.script_path,
        process_name: None,
        profile: is_profiling,
        profile_dir: cfg.profile.clone(),
        logs: is_logging,
        logs_dir: cfg.logs.clone(),
    };

    let result = if let Some(mut handle) = serve_handle {
        // Race the run against serve shutdown (Ctrl+C)
        let r = tokio::select! {
            r = cli_run::run_piped(&cfg.host, cfg.port, request) => r,
            _ = handle.shutdown_rx.recv() => {
                tracing::info!("Shutting down...");
                handle.kill_children().await;
                return Ok(rodeo_client::RunResult { exit_code: 130, ..Default::default() });
            }
        };
        // Graceful shutdown: close studio (triggers save if --save was used).
        // Skip when --detached — caller explicitly asked Studio to survive.
        if let Some(ref sid) = launched_studio_id {
            if !cfg.detached {
                let _ = RodeoClient::connect(&cfg.host, cfg.port)?.close_studio_raw(sid).await;
            }
        }
        drop(handle);
        r?
    } else {
        cli_run::run_piped(&cfg.host, cfg.port, request).await?
    };

    Ok(result)
}


// ---------------------------------------------------------------------------
// Play mode helpers
// ---------------------------------------------------------------------------

/// Check if a target string is a play mode target.
fn is_play_target(target: Option<&str>) -> bool {
    target.is_some_and(|t| t.starts_with("play:"))
}

/// Build a LaunchStudioRequest from CLI args for the LaunchStudio RPC.
async fn build_launch_request(
    target: &crate::studio_backend::PlaceTarget,
    background: bool,
    save: Option<String>,
    fflags: crate::cli::FflagArgs,
    detached: bool,
    no_hud: bool,
    profile: bool,
    logs: Option<String>,
    host: &str,
    port: u16,
) -> Result<rodeo_proto::LaunchStudioRequest> {
    // Find the studio backend to target
    let backends = RodeoClient::connect(host, port)?.list_backends(None).await?;
    let studio_backend = backends.iter().find(|b| b.kind == "studio")
        .ok_or_else(|| anyhow::anyhow!("no studio backend registered"))?;

    Ok(rodeo_proto::LaunchStudioRequest {
        backend: studio_backend.id.clone(),
        place_file: match target {
            crate::studio_backend::PlaceTarget::File(p) => Some(p.clone()),
            _ => None,
        },
        place_id: match target {
            crate::studio_backend::PlaceTarget::PlaceId { place_id, .. } => Some(*place_id),
            _ => None,
        },
        fflags: fflags.fflag_override,
        background,
        detached,
        no_hud,
        profile,
        save_path: save,
        fflag_file: fflags.fflag_file,
        logs_dir: logs,
        ..Default::default()
    })
}

/// Launch play server and/or clients based on the target.
/// Uses HTTP API to check existing state and spawn what's missing.
/// Handles to play-mode processes, cleaned up on Drop.
pub struct PlayHandles {
    server: Option<crate::studio_backend::MultiplayerTestServer>,
    clients: Vec<crate::studio_backend::MultiplayerTestClient>,
}

impl PlayHandles {
    pub fn cleanup(&mut self) {
        for client in &mut self.clients {
            client.cleanup();
        }
        if let Some(ref mut server) = self.server {
            server.cleanup();
        }
    }
}

impl Drop for PlayHandles {
    fn drop(&mut self) {
        self.cleanup();
    }
}

async fn launch_play_processes(
    host: &str,
    port: u16,
    target: &crate::shared::target::Target,
    place: Option<&crate::studio_backend::PlaceTarget>,
    background: bool,
    fflags: &crate::cli::FflagArgs,
    no_hud: bool,
    profile: bool,
) -> Result<PlayHandles> {
    use crate::shared::target::Dom;
    use crate::studio_backend::{MultiplayerTestClient, MultiplayerTestClientOptions, PlaceTarget};

    // Check if a play server is already running via the state API
    let master = master_client(host, port)?;
    let snapshot = master.get_state(proto::GetStateRequest::default()).await
        .ok().map(|r| r.into_owned());
    let has_play_server = snapshot.as_ref().map_or(false, |s| {
        s.vms.iter().any(|vm| vm.mode.as_deref() == Some("play") && vm.dom.as_deref() == Some("server"))
    });

    // Determine what needs to be launched
    let need_server = !has_play_server && place.is_some();
    let need_clients = target.dom == Dom::Client;
    let client_index = target.client_index; // None = append, Some(N) = ensure N

    tracing::debug!(
        has_play_server, need_server, need_clients,
        client_index = ?client_index,
        target_dom = ?target.dom,
        target_mode = ?target.mode,
        "launch_play_processes: decision"
    );

    if need_server || (need_clients && !has_play_server) {
        // Route server launch through the canonical
        // `launch_multiplayer_test_server` RPC on master. The studio backend
        // owns the StartServer process and reports MultiplayerTestServerReady
        // back to master; master fires Ready on the launch stream once the
        // play:server VM is registered, or Error if the process dies during
        // launch (no more 60s polling timeout).
        let (place_file_arg, place_id_arg): (Option<String>, Option<u64>) = match place.cloned() {
            Some(PlaceTarget::File(p)) => (Some(p), None),
            Some(PlaceTarget::PlaceId { place_id, .. }) => (None, Some(place_id)),
            Some(PlaceTarget::Empty) | Some(PlaceTarget::Content(_)) | None => (None, None),
        };

        tracing::info!("launching play server via master...");
        let mut stream = master.launch_multiplayer_test_server(proto::LaunchMultiplayerTestServerRequest {
            backend: String::new(),  // first studio backend
            place_file: place_file_arg,
            place_id: place_id_arg,
            fflags: fflags.fflag_override.clone(),
            profile,
            run_id: None,
            fflag_file: fflags.fflag_file.clone(),
            background,
            no_hud,
            ..Default::default()
        }).await.context("launch_multiplayer_test_server RPC failed")?;
        loop {
            let view = stream.message().await
                .context("launch_multiplayer_test_server stream errored")?
                .ok_or_else(|| anyhow::anyhow!("launch_multiplayer_test_server stream ended without Ready/Error"))?;
            let event = view.to_owned_message();
            match event.event {
                Some(proto::launch_multiplayer_test_server_event::Event::Ready(_)) => break,
                Some(proto::launch_multiplayer_test_server_event::Event::Error(err)) => {
                    anyhow::bail!("play server launch failed: {}", err.message);
                }
                _ => {}
            }
        }
        tracing::info!("play server registered with master");

        // Now launch requested clients (if any) — this CLI path assumes a single
        // session (CLI target syntax for multi-session is deferred). Read the
        // singleton session from state; error if zero or ambiguous.
        let mut launched_clients: Vec<MultiplayerTestClient> = Vec::new();
        if need_clients {
            let state = master.get_state(proto::GetStateRequest::default()).await
                .context("failed to query server state")?
                .into_owned();
            if state.multiplayer_test_sessions.len() != 1 {
                anyhow::bail!("expected exactly one play session for CLI client launch, got {}", state.multiplayer_test_sessions.len());
            }
            let session = state.multiplayer_test_sessions.into_iter().next().unwrap();
            let ps = session.server.into_option()
                .context("play session has no server info")?;
            let user_id = get_roblox_user_id().await?;
            let count = client_index.unwrap_or(1);
            for i in 1..=count {
                tracing::info!(index = i, "launching play client...");
                let _ = port; // generic client doesn't need the rodeo plugin port (plugin is shared with server)
                let client = MultiplayerTestClient::launch(MultiplayerTestClientOptions {
                    raknet_port: ps.raknet_port as u16,
                    raknet_session_guid: ps.raknet_session_guid.clone(),
                    server_pid: ps.pid,
                    play_test_guid: ps.play_test_guid.clone(),
                    index: i,
                    background,
                    user_id,
                    detached: false,
                    no_hud,
                    // CLI inline-client path: state snapshot doesn't surface the
                    // session's published-place ids today, so the client launches
                    // anonymous. The canonical path (LaunchMultiplayerTestClient
                    // dispatched by the backend) DOES forward them.
                    place_id: 0,
                    universe_id: 0,
                    place_version: 0,
                })?;
                tracing::info!(index = i, pid = client.pid(), "play client running");
                launched_clients.push(client);
            }
        }

        // Server is owned by the studio backend; we own only clients we spawned
        // inline (if any).
        return Ok(PlayHandles { server: None, clients: launched_clients });
    } else if need_clients && has_play_server {
        // Server exists, spawn requested client(s) via the canonical ConnectClient
        // RPC. Studio backend owns the Child handles, so they die when the
        // server's session drops (Rust ownership cascade).
        // CLI assumes a single session — read it from state; error if ambiguous.
        let state = master.get_state(proto::GetStateRequest::default()).await
            .context("failed to query server state")?
            .into_owned();
        if state.multiplayer_test_sessions.len() != 1 {
            anyhow::bail!(
                "expected exactly one play session for CLI client launch, got {}",
                state.multiplayer_test_sessions.len()
            );
        }
        let session = state.multiplayer_test_sessions.into_iter().next().unwrap();
        let session_id = session.session_guid;
        let existing_clients = session.clients.len() as u32;

        // How many clients to request, and at what target indices for wait logic.
        let to_spawn = match client_index {
            Some(n) => n.saturating_sub(existing_clients).max(1),
            None => 1,
        };

        tracing::info!(session_id = %session_id, to_spawn, existing_clients, ?client_index, "spawning play clients via ConnectClient RPC");

        for _ in 0..to_spawn {
            master.connect_multiplayer_test_client(proto::ConnectMultiplayerTestClientRequest {
                session_guid: session_id.clone(),
                ..Default::default()
            }).await.context("connect_multiplayer_test_client RPC failed")?;
        }

        // Wait for the expected number of play:client VMs to register so
        // subsequent run-submit targeting play:client:N can route.
        let expected_total = existing_clients + to_spawn;
        let deadline = std::time::Instant::now() + std::time::Duration::from_secs(60);
        loop {
            let snap = master.get_state(proto::GetStateRequest::default()).await
                .context("failed to query state while waiting for play clients")?
                .into_owned();
            let connected = snap.vms.iter()
                .filter(|vm| vm.mode.as_deref() == Some("play") && vm.dom.as_deref() == Some("client") && vm.connected)
                .count() as u32;
            if connected >= expected_total {
                break;
            }
            if std::time::Instant::now() >= deadline {
                anyhow::bail!("timed out waiting for play clients to register (expected >= {}, got {})", expected_total, connected);
            }
            tokio::time::sleep(std::time::Duration::from_millis(250)).await;
        }

        return Ok(PlayHandles { server: None, clients: vec![] });
    }

    // Wait for plugin connections
    tracing::info!("waiting for play VMs to connect...");
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(30);
    loop {
        if std::time::Instant::now() > deadline {
            bail!("timeout waiting for play VMs to connect");
        }
        tokio::time::sleep(std::time::Duration::from_millis(500)).await;

        if let Ok(resp) = master.get_state(proto::GetStateRequest::default()).await {
            let state = resp.into_owned();
            let play_vms: Vec<_> = state.vms.iter()
                .filter(|vm| vm.mode.as_deref() == Some("play"))
                .collect();

            let has_server = play_vms.iter().any(|vm| vm.dom.as_deref() == Some("server"));
            let client_count = play_vms.iter().filter(|vm| vm.dom.as_deref() == Some("client")).count();

            let needed_clients = if target.dom == Dom::Client {
                target.client_index.unwrap_or(1) as usize
            } else {
                0
            };

            if (target.dom == Dom::Server && has_server) ||
               (target.dom == Dom::Client && has_server && client_count >= needed_clients)
            {
                tracing::info!(server = has_server, clients = client_count, "play VMs connected");
                break;
            }
        }
    }

    Ok(PlayHandles { server: None, clients: vec![] })
}

/// Get the current Roblox user ID from the auth cookie.
pub(crate) async fn get_roblox_user_id() -> Result<u64> {
    let cookie = rbx_cookie::get()
        .context("failed to get Roblox auth cookie — is Studio logged in?")?;

    let client = crate::util::http::client();
    let resp = client
        .get("https://users.roblox.com/v1/users/authenticated")
        .header("Cookie", &cookie)
        .send()
        .await
        .context("failed to reach Roblox users API")?;

    if !resp.status().is_success() {
        bail!("Roblox users API returned {} — auth cookie may be expired", resp.status());
    }

    let body: serde_json::Value = resp.json().await
        .context("failed to parse Roblox users API response")?;

    body["id"]
        .as_u64()
        .context("Roblox users API response missing user id")
}
