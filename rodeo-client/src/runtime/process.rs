use super::{SharedRpcState, StreamHandler};
use rodeo_proto::runtime_types as rt;

/// Locate the Studio `content/` directory via `roblox_install`. Same logic as
/// `rbx_control::studio::launch::studio_content_path`, duplicated here so
/// rodeo-client doesn't take a dep on rbx-control.
fn studio_content_path() -> Option<String> {
    roblox_install::RobloxStudio::locate()
        .ok()
        .map(|s| s.content_path().to_string_lossy().to_string())
}

fn format_process_output(output: &std::process::Output) -> rt::ProcessRunResponse {
    rt::ProcessRunResponse {
        ok: output.status.success(),
        exitcode: output.status.code().unwrap_or(-1),
        out: String::from_utf8_lossy(&output.stdout).to_string(),
        err: String::from_utf8_lossy(&output.stderr).to_string(),
        ..Default::default()
    }
}

pub fn process_get_info(_req: &rt::ProcessGetInfoRequest) -> Result<rt::ProcessGetInfoResponse, String> {
    Ok(rt::ProcessGetInfoResponse {
        cwd: std::env::current_dir()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default(),
        // HOME on Unix; Windows normally has no HOME, so fall back to USERPROFILE.
        homedir: std::env::var("HOME")
            .or_else(|_| std::env::var("USERPROFILE"))
            .unwrap_or_default(),
        execpath: std::env::current_exe()
            .map(|p| p.to_string_lossy().to_string())
            .unwrap_or_default(),
        env: std::env::vars().collect(),
        platform: Some(std::env::consts::OS.to_string()),
        arch: Some(std::env::consts::ARCH.to_string()),
        studio_content_path: studio_content_path(),
        ..Default::default()
    })
}

pub async fn process_exit(state: SharedRpcState, req: &rt::ProcessExitRequest) -> Result<rt::Ok, String> {
    state.lock().await.exit_code = req.code;
    Ok(rt::Ok::default())
}

fn build_command(program: &str, args: &[String], opts: Option<&rt::ProcessOptions>) -> tokio::process::Command {
    let mut cmd = tokio::process::Command::new(program);
    cmd.args(args);
    if let Some(o) = opts {
        if let Some(cwd) = &o.cwd {
            cmd.current_dir(cwd);
        }
    }
    cmd
}

pub async fn process_run(req: &rt::ProcessRunRequest) -> Result<rt::ProcessRunResponse, String> {
    if req.args.is_empty() {
        return Err("empty args".to_string());
    }
    let program = &req.args[0];
    let program_args = &req.args[1..];
    let mut cmd = build_command(program, program_args, req.options.as_option());
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());
    let output = cmd.output().await.map_err(|e| format!("run error: {e}"))?;
    Ok(format_process_output(&output))
}

pub async fn process_system(req: &rt::ProcessSystemRequest) -> Result<rt::ProcessRunResponse, String> {
    // Shell out via the platform's shell: `sh -c` on Unix, `cmd /C` on Windows
    // (there is no `sh` on a stock Windows install).
    let (shell, flag) = if cfg!(windows) { ("cmd", "/C") } else { ("sh", "-c") };
    let mut cmd = build_command(shell, &[flag.to_string(), req.command.clone()], req.options.as_option());
    cmd.stdout(std::process::Stdio::piped());
    cmd.stderr(std::process::Stdio::piped());
    let output = cmd.output().await.map_err(|e| format!("system error: {e}"))?;
    Ok(format_process_output(&output))
}

pub async fn process_create(state: SharedRpcState, req: &rt::ProcessCreateRequest) -> Result<rt::ProcessCreateResponse, String> {
    if req.args.is_empty() {
        return Err("empty args".to_string());
    }
    let program = &req.args[0];
    let program_args = &req.args[1..];
    let is_piped = req
        .options
        .as_option()
        .and_then(|o| o.stdio.as_deref())
        .map(|s| s == "piped")
        .unwrap_or(false);

    let mut cmd = build_command(program, program_args, req.options.as_option());
    if is_piped {
        cmd.stdin(std::process::Stdio::piped());
        cmd.stdout(std::process::Stdio::piped());
        cmd.stderr(std::process::Stdio::piped());
    }
    let mut child = cmd.spawn().map_err(|e| format!("create error: {e}"))?;

    let mut guard = state.lock().await;
    guard.next_pid += 1;
    let pid = guard.next_pid.to_string();

    let mut resp = rt::ProcessCreateResponse {
        pid: pid.clone(),
        ..Default::default()
    };

    if is_piped {
        let stdin_handle = format!("proc:{pid}:stdin");
        let stdout_handle = format!("proc:{pid}:stdout");
        let stderr_handle = format!("proc:{pid}:stderr");

        guard.stream_handlers.insert(stdin_handle.clone(), StreamHandler::ProcessStdin { stdin: child.stdin.take() });
        guard.stream_handlers.insert(stdout_handle.clone(), StreamHandler::ProcessStdout { stdout: child.stdout.take() });
        guard.stream_handlers.insert(stderr_handle.clone(), StreamHandler::ProcessStderr { stderr: child.stderr.take() });

        resp.stdin_handle = Some(stdin_handle);
        resp.stdout_handle = Some(stdout_handle);
        resp.stderr_handle = Some(stderr_handle);
    }

    guard.child_processes.insert(pid, child);
    Ok(resp)
}

pub async fn process_run_handle(state: SharedRpcState, req: &rt::ProcessRunHandleRequest) -> Result<rt::ProcessRunResponse, String> {
    let child = {
        let mut guard = state.lock().await;
        guard
            .child_processes
            .remove(&req.pid)
            .ok_or_else(|| format!("unknown pid: {}", req.pid))?
    };
    let output = child.wait_with_output().await.map_err(|e| format!("wait error: {e}"))?;
    Ok(format_process_output(&output))
}

pub async fn process_kill(state: SharedRpcState, req: &rt::ProcessKillRequest) -> Result<rt::Ok, String> {
    let mut guard = state.lock().await;
    if let Some(child) = guard.child_processes.get_mut(&req.pid) {
        let _ = child.start_kill();
    }
    Ok(rt::Ok::default())
}
