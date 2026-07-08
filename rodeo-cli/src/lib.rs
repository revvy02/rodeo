pub mod cli;
mod cli_run;
mod commands;
mod master;
mod studio_backend;
mod shared;
mod runtime;
mod util;

use clap::{CommandFactory, FromArgMatches};
use cli::{Cli, Commands};
use util::config;

fn build_banner() -> String {
    let version = env!("CARGO_PKG_VERSION");
    let left_label = format!(" v{version} ");
    let right_label = " rvy ";
    let pad = 3;

    let art: &[&str] = &[
        "██████╗  ██████╗ ██████╗ ███████╗ ██████╗",
        "██╔══██╗██╔═══██╗██╔══██╗██╔════╝██╔═══██╗",
        "██████╔╝██║   ██║██║  ██║█████╗  ██║   ██║",
        "██╔══██╗██║   ██║██║  ██║██╔══╝  ██║   ██║",
        "██║  ██║╚██████╔╝██████╔╝███████╗╚██████╔╝",
        "╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝ ╚═════╝",
    ];

    let max_w = art.iter().map(|l| l.chars().count()).max().unwrap();
    let inner = max_w + pad * 2;
    let left_len = left_label.chars().count();
    let right_len = right_label.chars().count();
    let fill = inner.saturating_sub(left_len + right_len + 4);

    let mut out = String::new();

    out += &format!(
        "\x1b[33m╭──{}{}{}──╮\x1b[0m\n",
        left_label,
        "─".repeat(fill),
        right_label,
    );

    let empty_row = format!(
        "\x1b[33m│\x1b[0m{}\x1b[33m│\x1b[0m\n",
        " ".repeat(inner),
    );
    out += &empty_row;

    for line in art {
        let w = line.chars().count();
        let right_pad = inner - pad - w;
        out += &format!(
            "\x1b[33m│\x1b[0m{}\x1b[1;31m{}\x1b[0m{}\x1b[33m│\x1b[0m\n",
            " ".repeat(pad),
            line,
            " ".repeat(right_pad),
        );
    }

    out += &empty_row;
    out += &format!("\x1b[33m╰{}╯\x1b[0m", "─".repeat(inner));

    out
}

/// Long flags clap parses as `Vec<T>` — directive and CLI both contribute, so
/// these are exempt from the directive-token override filter. Keep in sync if
/// new repeatable args are added to `Commands::Run` (or other commands that
/// participate in the directive splice).
const REPEATABLE_DIRECTIVE_FLAGS: &[&str] = &["--fflag.override"];

/// Drop directive flag tokens whose long-name matches a user-supplied CLI
/// flag, so clap's "argument cannot be used multiple times" rejection
/// doesn't fire on directive↔CLI overlap. Scalar override semantics: user
/// CLI wins for any flag they passed. Repeatable Vec flags (see
/// `REPEATABLE_DIRECTIVE_FLAGS`) pass through unfiltered so values accumulate.
fn filter_directive_for_overrides(directive: &[String], user_after_run: &[String]) -> Vec<String> {
    let user_flags: std::collections::HashSet<&str> = user_after_run
        .iter()
        .filter(|t| t.starts_with("--") && t.len() > 2)
        .map(|t| t.split('=').next().unwrap())
        .collect();

    let mut out = Vec::with_capacity(directive.len());
    let mut i = 0;
    while i < directive.len() {
        let tok = &directive[i];
        if tok.starts_with("--") && tok.len() > 2 {
            let flag_name = tok.split('=').next().unwrap();
            let repeatable = REPEATABLE_DIRECTIVE_FLAGS.contains(&flag_name);
            if user_flags.contains(flag_name) && !repeatable {
                i += 1;
                let has_inline_value = tok.contains('=');
                if !has_inline_value
                    && i < directive.len()
                    && !directive[i].starts_with("--")
                {
                    i += 1;
                }
                continue;
            }
        }
        out.push(directive[i].clone());
        i += 1;
    }
    out
}

/// Library entry point: parses CLI, dispatches subcommands. main.rs is the
/// thin binary wrapper that builds the tokio runtime and calls this.
pub async fn run() {
    // Load .env file if present (shell env vars take precedence)
    let _ = dotenvy::dotenv();

    // Tell launch-control to dispatch helper invocations through us via
    // the `__launch-control` subcommand. Single binary — no separate
    // helper file to deploy or unpack.
    if let Ok(exe) = std::env::current_exe() {
        launch_control::set_helper_invocation(exe, vec!["__launch-control".into()]);
    }

    let banner = build_banner();
    let matches = Cli::command()
        .before_help(banner.clone())
        .get_matches();
    let cli = Cli::from_arg_matches(&matches)
        .unwrap_or_else(|e| e.exit());

    // If this is `rodeo run <script>`, read the script's `@rodeo run …`
    // directive (if any) and splice its flag tokens into argv right after
    // the `run` subcommand. Then re-parse via clap so directive flags flow
    // through the same arg pipeline as the CLI — no per-field merge code,
    // adding a new CLI arg works in directives automatically.
    //
    // CLI precedence: any flag the user passed on the CLI is removed from
    // the directive tokens before splicing, so clap doesn't see duplicate
    // occurrences (which it rejects by default for scalar `Option<T>`).
    // Vec-typed flags in `REPEATABLE_DIRECTIVE_FLAGS` are exempt — both
    // directive and CLI values accumulate.
    let (cli, directive_script_args) = match &cli.command {
        Commands::Run { script: Some(script_arg), .. } => {
            let resolved = commands::process_source::directive::resolve_script_path(script_arg);
            match std::fs::read_to_string(&resolved)
                .ok()
                .and_then(|c| commands::process_source::directive::parse_directive(&c))
            {
                Some(tokens) if !tokens.flag_args.is_empty() || !tokens.script_args.is_empty() => {
                    let argv: Vec<String> = std::env::args().collect();
                    let run_idx = argv.iter().position(|a| a == "run")
                        .expect("matched Run subcommand but no 'run' in argv");
                    let user_after_run: &[String] = &argv[run_idx + 1..];
                    let filtered = filter_directive_for_overrides(&tokens.flag_args, user_after_run);
                    // User argv first, then directive tokens. The user's
                    // positional (script path) must be parsed before any
                    // `num_args = 0..=1` flags in the directive (e.g.
                    // `--place`), otherwise clap greedily consumes the
                    // positional as the flag's value and downstream tries to
                    // open the script as a place file ("failed to parse
                    // binary place"). Override semantics still hold because
                    // `filter_directive_for_overrides` already dropped any
                    // directive flag the user also passed.
                    let mut spliced = argv[..=run_idx].to_vec();
                    spliced.extend(user_after_run.iter().cloned());
                    spliced.extend(filtered);
                    let re_parsed = Cli::command()
                        .before_help(banner)
                        .get_matches_from(spliced);
                    let cli = Cli::from_arg_matches(&re_parsed)
                        .unwrap_or_else(|e| e.exit());
                    (cli, tokens.script_args)
                }
                _ => (cli, Vec::new()),
            }
        }
        _ => (cli, Vec::new()),
    };

    let verbose = cli.verbose || std::env::var("RODEO_VERBOSE").is_ok();
    util::log::init();

    // Long-running subprocesses (master, studio-backend, player-backend,
    // studio-daemon) capture structured JSON logs to .rodeo/.temp/logs/ in
    // addition to stderr — see util::log_capture. All other commands
    // (run, ps, kill, save, etc.) keep the existing stderr-only subscriber.
    //
    // For the master specifically, the bootstrap UUID doubles as `master_id`
    // advertised to backends in `RegisterResponse` — we stash it in an Option
    // so the `InternalMaster` branch below can pass it into `run_master`.
    let subprocess_role: Option<&'static str> = match &cli.command {
        Commands::InternalMaster { .. } => Some("master"),
        Commands::InternalStudioBackend { .. } => Some("studio-backend"),
        _ => None,
    };
    let master_bootstrap_id: Option<String> = if let Some(role) = subprocess_role {
        let bootstrap_id = uuid::Uuid::new_v4().to_string();
        util::log_capture::init(role, &bootstrap_id);
        if role == "master" { Some(bootstrap_id) } else { None }
    } else {
        // Initialize tracing subscriber (existing behavior for non-subprocess commands)
        use tracing_subscriber::EnvFilter;
        let quiet_serve = !verbose && matches!(&cli.command, Commands::Run { .. });

        if quiet_serve && std::env::var_os("RUST_LOG").is_none() {
            std::env::set_var("RODEO_QUIET", "1");
        }

        let filter = EnvFilter::try_from_env("RUST_LOG")
            .unwrap_or_else(|_| {
                if verbose {
                    EnvFilter::new("rodeo=debug")
                } else if quiet_serve {
                    EnvFilter::new("rodeo=warn")
                } else {
                    EnvFilter::new("rodeo=info")
                }
            });
        use std::io::IsTerminal;
        let no_color = std::env::var("NO_COLOR").is_ok_and(|v| !v.is_empty());
        let force_color = std::env::var("FORCE_COLOR").is_ok_and(|v| !v.is_empty());
        let use_ansi = !no_color && (force_color || std::io::stderr().is_terminal());

        let no_timestamps = std::env::var("RODEO_NO_TIMESTAMPS").is_ok();
        if no_timestamps {
            tracing_subscriber::fmt()
                .with_env_filter(filter)
                .with_target(false)
                .with_writer(std::io::stderr)
                .with_ansi(use_ansi)
                .without_time()
                .init();
        } else {
            tracing_subscriber::fmt()
                .with_env_filter(filter)
                .with_target(false)
                .with_writer(std::io::stderr)
                .with_ansi(use_ansi)
                .init();
        }
        None
    };

    let result = match cli.command {
        Commands::Serve { port, master, studio_mode, master_host, master_port, ppid } => {
            if let Some(ppid) = ppid { parent_exit::on_parent_exit(ppid); }
            let mode = if master {
                commands::serve::ServeMode::Master
            } else if studio_mode {
                commands::serve::ServeMode::Studio {
                    master_host,
                    master_port: master_port.unwrap_or(config::SERVE_PORT),
                }
            } else {
                commands::serve::ServeMode::Combined
            };
            commands::serve::main(port, mode).await
        }
        Commands::Run { script, source, sourcemap, output, return_file, show_return, target, studio: _, no_warn, no_error, no_info, no_print, no_output, cache_requires, script_args, ppid, server, place, fflags } => {
            if let Some(ppid) = ppid { parent_exit::on_parent_exit(ppid); }
            let script_args = if script_args.is_empty() { directive_script_args } else { script_args };
            commands::run::main(commands::run::RunArgs {
                script, source, sourcemap, output, return_file, show_return, target,
                no_warn, no_error, no_info, no_print, no_output,
                cache_requires, script_args,
                server, place, fflags,
                verbose,
            }).await
        }
        Commands::State { json, server } => commands::state::main(&server.host, server.port, json).await,
        Commands::Kill { id, server } => commands::kill::main(&id, &server.host, server.port).await,
        Commands::Save { out, server } => commands::save::main(&server.host, server.port, out).await,
        Commands::Plugin => commands::plugin::main(),
        Commands::Setup => commands::setup::main(),
        Commands::Mcp { server } => commands::mcp::main(&server.host, server.port).await,
        Commands::InternalMaster { port, ppid } => {
            if let Some(ppid) = ppid { parent_exit::on_parent_exit(ppid); }
            let master_id = master_bootstrap_id.unwrap_or_default();
            commands::serve::run_master(port, master_id).await
        }
        Commands::InternalStudioBackend { port, master_host, master_port, ppid } => {
            if let Some(ppid) = ppid { parent_exit::on_parent_exit(ppid); }
            commands::serve::run_studio_backend(port, &master_host, master_port).await
        }
        Commands::ProcessSource { script, source, sourcemap } => {
            commands::process_source::main(script, source, sourcemap)
                .map_err(|e| { eprintln!("{e}"); e })
        }
        Commands::SpawnCanonicalClient { host, port } => {
            commands::spawn_canonical_client::main(host, port).await
        }
    };

    if let Err(e) = result {
        tracing::error!("{e:#}");
        std::process::exit(1);
    }
}
