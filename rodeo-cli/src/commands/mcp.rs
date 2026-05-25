use anyhow::Result;
use std::io::{BufRead, Write};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;

use crate::cli_run::{self, RunRequest};
use rodeo_client::RodeoClient;
use crate::commands::process_source;
use rbx_control::studio::mcp_client::StudioMcpClient;
use rodeo_proto as proto;

const SERVER_INSTRUCTIONS: &str = "\
rodeo executes Luau code inside Roblox Studio via WebSocket.

VM Targeting (--target): <mode>:<dom>[:<identity>]
- edit:plugin (default) — edit DataModel, ModuleScript
- run:server — run mode server, Script
- test:server / test:client — play test server/client
- play:server / play:client — multi-client test
- Append :plugin or :elevated to override identity

Direct targeting:
- vm: target a specific VM by ID (from get_state)
- job: target a specific game server by job ID

Launch:
- place: launch Studio (empty = new place, number = place ID, string = file path)

Return values: Scripts can return values. Use run_code to both query data and make changes.
Use get_state to discover available VMs, studios, and processes.
";

// --- Luau tool discovery ---

struct LuauTool {
    name: String,
    description: String,
    script: String,
    target: String,
    input_schema: Option<serde_json::Value>,
    annotations: Option<serde_json::Value>,
}

/// Parse the leading `--[[ ... ]]` header of a Luau tool source.
///
/// Supported directives:
///   `@rodeo run --target <target>` — inline; sets the VM target
///   `@rodeo schema` — claims subsequent non-`@rodeo` lines as JSON inputSchema
///   `@rodeo annotations` — claims subsequent non-`@rodeo` lines as JSON annotations
///
/// All other non-`@rodeo` lines are concatenated into the tool description.
/// `schema` / `annotations` consume lines until the next `@rodeo` directive or
/// the end of the block, so place them last in the header.
fn parse_luau_header(source: &str) -> (String, String, Option<serde_json::Value>, Option<serde_json::Value>) {
    let mut description = String::new();
    let mut target = "edit:plugin".to_string();
    let mut schema: Option<serde_json::Value> = None;
    let mut annotations: Option<serde_json::Value> = None;

    let Some(start) = source.find("--[[") else { return (description, target, schema, annotations); };
    let block_start = start + 4;
    let Some(rel_end) = source[block_start..].find("]]") else { return (description, target, schema, annotations); };
    let block = &source[block_start..block_start + rel_end];

    #[derive(PartialEq)]
    enum Section { Description, Schema, Annotations }
    let mut current = Section::Description;
    let mut buffer = String::new();

    let flush = |sec: &Section, buf: &str, schema: &mut Option<serde_json::Value>, annotations: &mut Option<serde_json::Value>| {
        let trimmed = buf.trim();
        if trimmed.is_empty() { return; }
        match sec {
            Section::Schema => { *schema = serde_json::from_str(trimmed).ok(); }
            Section::Annotations => { *annotations = serde_json::from_str(trimmed).ok(); }
            Section::Description => {}
        }
    };

    for line in block.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("@rodeo ") {
            flush(&current, &buffer, &mut schema, &mut annotations);
            buffer.clear();

            let mut parts = rest.splitn(2, char::is_whitespace);
            let name = parts.next().unwrap_or("");
            let inline = parts.next().unwrap_or("").trim();

            match name {
                "run" => {
                    if let Some(t) = inline.split("--target").nth(1) {
                        target = t.trim().split_whitespace().next().unwrap_or("edit:plugin").to_string();
                    }
                    current = Section::Description;
                }
                "schema" => {
                    current = Section::Schema;
                    if !inline.is_empty() { buffer.push_str(inline); }
                }
                "annotations" => {
                    current = Section::Annotations;
                    if !inline.is_empty() { buffer.push_str(inline); }
                }
                _ => { current = Section::Description; }
            }
        } else if current == Section::Description {
            if !trimmed.is_empty() {
                if !description.is_empty() { description.push(' '); }
                description.push_str(trimmed);
            }
        } else {
            if !buffer.is_empty() { buffer.push('\n'); }
            buffer.push_str(line);
        }
    }
    flush(&current, &buffer, &mut schema, &mut annotations);

    (description, target, schema, annotations)
}

fn discover_luau_tools() -> Vec<LuauTool> {
    let dir = std::path::Path::new("build/mcp");
    if !dir.is_dir() {
        return vec![];
    }

    let mut tools = vec![];
    let Ok(entries) = std::fs::read_dir(dir) else {
        return vec![];
    };

    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("luau") {
            continue;
        }
        let name = path.file_stem().and_then(|s| s.to_str()).unwrap_or("").to_string();
        let Ok(source) = std::fs::read_to_string(&path) else { continue };

        let (description, target, input_schema, annotations) = parse_luau_header(&source);

        tools.push(LuauTool { name, description, script: source, target, input_schema, annotations });
    }

    tools
}

// --- Remap config ---

#[derive(Debug, serde::Deserialize, Default)]
struct RemapEntry {
    #[serde(default)]
    exclude: bool,
    name: Option<String>,
    description: Option<String>,
}

type RemapConfig = HashMap<String, RemapEntry>;

fn load_remap_config() -> RemapConfig {
    let path = std::path::Path::new("rodeo-mcp/rodeo-studio-mcp-remap.json");
    if path.exists() {
        if let Ok(contents) = std::fs::read_to_string(path) {
            if let Ok(config) = serde_json::from_str(&contents) {
                return config;
            }
        }
    }
    let mut defaults = HashMap::new();
    defaults.insert("execute_luau".into(), RemapEntry { exclude: true, ..Default::default() });
    defaults.insert("start_stop_play".into(), RemapEntry { exclude: true, ..Default::default() });
    defaults
}

// --- Tool registry ---

struct ToolDef {
    name: String,
    description: String,
    input_schema: serde_json::Value,
    output_schema: Option<serde_json::Value>,
    annotations: Option<serde_json::Value>,
    kind: ToolKind,
}

enum ToolKind {
    RunCode,
    GetProcesses,
    KillProcess,
    GetState,
    GetStudios,
    GetBackends,
    SavePlace,
    Luau { script: String, target: String },
    StudioProxy { original_name: String },
}

fn build_builtin_tools() -> Vec<ToolDef> {
    vec![
        ToolDef {
            name: "run_code".into(),
            description: "Execute Luau code in a Roblox Studio VM matched by `target`. \
                If no live VM matches the requested target, Studio will transition into \
                that mode first (e.g. entering play test) before running — this mutates \
                Studio state and may take several seconds. Append `:elevated` to a target \
                (e.g. `edit:elevated`) to run at command-bar identity instead of plugin \
                identity; required for privileged Roblox APIs like `DebuggerManager`. \
                Use `get_studios` to see what VMs are currently alive.".into(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": {
                    "code": { "type": "string", "description": "Luau code to execute. Can return a value." },
                    "target": {
                        "type": "string",
                        "description": "VM target. Grammar: <mode>:<dom>[:plugin|:elevated]. \
                            Modes: edit, run, test, play. Doms: plugin, server, client. \
                            Requesting a mode that isn't currently active will transition Studio into it. \
                            Append :elevated for command-bar identity (privileged Roblox APIs).",
                        "examples": [
                            "edit:plugin",
                            "edit:elevated",
                            "run:server",
                            "run:server:elevated",
                            "test:server",
                            "test:client",
                            "test:server:elevated",
                            "play:client"
                        ]
                    },
                    "vm": { "type": "string", "description": "Direct VM ID (bypasses target matching)" },
                    "job": { "type": "string", "description": "Filter by game server job ID" },
                    "backend": { "type": "string", "description": "Target specific backend device (name or ID)" },
                    "place": { "type": "string", "description": "Launch Studio: empty = new place, number = place ID, path = .rbxl file" },
                    "args": { "type": "array", "items": { "type": "string" }, "description": "Script arguments (accessible via require('@rodeo/process').args)" },
                    "cache_requires": { "type": "boolean", "description": "Use cached module state" },
                    "output": { "type": "string", "description": "Write output to file path" },
                    "return_file": { "type": "string", "description": "Write return value to file path" },
                    "detached": { "type": "boolean", "description": "Keep Studio alive after execution" },
                    "sourcemap": { "type": "string", "description": "Path to sourcemap.json for require resolution" },
                    "instance_path": { "type": "string", "description": "Instance path for the script" },
                    "profile": { "type": "boolean", "description": "Capture a microprofiler dump for this run" },
                    "profile_dir": { "type": "string", "description": "Directory to write the profile dump into (implies profile=true)" },
                    "logs": { "type": "boolean", "description": "Capture Studio log_*.txt files for this run" },
                    "logs_dir": { "type": "string", "description": "Directory to write captured logs into (implies logs=true)" }
                },
                "required": ["code"]
            }),
            output_schema: Some(serde_json::json!({
                "type": "object",
                "properties": {
                    "stdout": { "type": "string", "description": "Combined stdout/stderr from the script run." },
                    "return_value": { "type": ["string", "null"], "description": "Raw JSON-encoded return value, or null if the script returned nothing." },
                    "exit_code": { "type": "integer", "description": "0 on success, non-zero on script error or runtime failure." },
                    "error": { "type": ["string", "null"], "description": "Failure message when exit_code is non-zero." }
                },
                "required": ["stdout", "exit_code"]
            })),
            annotations: Some(serde_json::json!({
                "destructiveHint": true,
                "idempotentHint": false,
                "openWorldHint": true
            })),
            kind: ToolKind::RunCode,
        },
        ToolDef {
            name: "get_state".into(),
            description: "Get the full canonical rodeo state: studios, backends, VMs, and processes.".into(),
            input_schema: serde_json::json!({ "type": "object" }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "readOnlyHint": true,
                "idempotentHint": true
            })),
            kind: ToolKind::GetState,
        },
        ToolDef {
            name: "get_studios".into(),
            description: "Get connected Studio instances with mode, VMs, and place info.".into(),
            input_schema: serde_json::json!({ "type": "object" }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "readOnlyHint": true,
                "idempotentHint": true
            })),
            kind: ToolKind::GetStudios,
        },
        ToolDef {
            name: "get_backends".into(),
            description: "Get connected backend devices with names and VM counts.".into(),
            input_schema: serde_json::json!({ "type": "object" }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "readOnlyHint": true,
                "idempotentHint": true
            })),
            kind: ToolKind::GetBackends,
        },
        ToolDef {
            name: "get_processes".into(),
            description: "List all processes (queued, running, completed).".into(),
            input_schema: serde_json::json!({ "type": "object" }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "readOnlyHint": true,
                "idempotentHint": true
            })),
            kind: ToolKind::GetProcesses,
        },
        ToolDef {
            name: "kill_process".into(),
            description: "Kill a running process by ID.".into(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": { "id": { "type": "integer", "description": "Process ID (from get_processes)" } },
                "required": ["id"]
            }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "destructiveHint": true,
                "idempotentHint": true
            })),
            kind: ToolKind::KillProcess,
        },
        ToolDef {
            name: "save_place".into(),
            description: "Save the Studio place file.".into(),
            input_schema: serde_json::json!({
                "type": "object",
                "properties": { "out": { "type": "string", "description": "Copy saved file to this path" } }
            }),
            output_schema: None,
            annotations: Some(serde_json::json!({
                "destructiveHint": false,
                "idempotentHint": true
            })),
            kind: ToolKind::SavePlace,
        },
    ]
}

fn build_luau_tools(luau_tools: Vec<LuauTool>) -> Vec<ToolDef> {
    luau_tools.into_iter().map(|lt| ToolDef {
        name: lt.name,
        description: lt.description,
        input_schema: lt.input_schema.unwrap_or_else(|| serde_json::json!({ "type": "object" })),
        output_schema: None,
        annotations: lt.annotations,
        kind: ToolKind::Luau { script: lt.script, target: lt.target },
    }).collect()
}

async fn add_studio_proxy_tools(tools: &mut Vec<ToolDef>, studio_mcp: &mut Option<StudioMcpClient>) -> Result<(), String> {
    let remap = load_remap_config();
    let mut mcp_client = StudioMcpClient::new("rodeo").await?;

    let mcp_tools = {
        let mut attempts = 0;
        loop {
            let list = mcp_client.list_tools().await?;
            if !list.is_empty() { break list; }
            attempts += 1;
            if attempts > 10 {
                return Err("StudioMCP has no tools. Enable MCP Server in Studio AI Assistant settings.".into());
            }
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
    };

    let existing: std::collections::HashSet<String> = tools.iter().map(|t| t.name.clone()).collect();

    for tool_value in mcp_tools {
        let original_name = tool_value["name"].as_str().unwrap_or("").to_string();
        if let Some(entry) = remap.get(&original_name) {
            if entry.exclude { continue; }
        }
        let tool_name = remap.get(&original_name)
            .and_then(|e| e.name.clone())
            .unwrap_or_else(|| original_name.clone());
        if existing.contains(&tool_name) { continue; }

        let description = remap.get(&original_name)
            .and_then(|e| e.description.clone())
            .or_else(|| tool_value["description"].as_str().map(String::from))
            .unwrap_or_default();

        tools.push(ToolDef {
            name: tool_name,
            description,
            input_schema: tool_value["inputSchema"].clone(),
            output_schema: tool_value.get("outputSchema").cloned(),
            annotations: tool_value.get("annotations").cloned(),
            kind: ToolKind::StudioProxy { original_name },
        });
    }

    *studio_mcp = Some(mcp_client);
    Ok(())
}

// --- Tool execution ---

enum ToolResult {
    Text(Result<String, String>),
    Json(serde_json::Value),
    Raw(serde_json::Value),
    Structured { text: String, structured: serde_json::Value, is_error: bool },
}

struct RunCodeOutput {
    stdout: String,
    return_value: Option<String>,
    exit_code: i32,
    error: Option<String>,
}

impl RunCodeOutput {
    fn to_structured(&self) -> serde_json::Value {
        serde_json::json!({
            "stdout": self.stdout,
            "return_value": self.return_value,
            "exit_code": self.exit_code,
            "error": self.error,
        })
    }

    fn to_text(&self) -> String {
        let mut s = String::new();
        if !self.stdout.is_empty() { s.push_str(&self.stdout); }
        if let Some(ret) = &self.return_value {
            if !ret.is_empty() {
                if !s.is_empty() { s.push('\n'); }
                s.push_str("[return] ");
                s.push_str(ret);
            }
        }
        if let Some(err) = &self.error {
            if s.is_empty() { s = err.clone(); }
        }
        if s.is_empty() { s = "OK".to_string(); }
        s
    }
}

async fn execute_tool(
    tool: &ToolDef,
    args: &serde_json::Value,
    host: &str,
    port: u16,
    studio_mcp: &Arc<Mutex<Option<StudioMcpClient>>>,
) -> ToolResult {
    match &tool.kind {
        ToolKind::RunCode => {
            let output = handle_run_code(host, port, args).await;
            let is_error = output.exit_code != 0;
            ToolResult::Structured {
                text: output.to_text(),
                structured: output.to_structured(),
                is_error,
            }
        }
        ToolKind::GetState => ToolResult::Json(handle_get_state(host, port).await),
        ToolKind::GetStudios => ToolResult::Json(handle_get_slice(host, port, "studios").await),
        ToolKind::GetBackends => ToolResult::Json(handle_get_slice(host, port, "backends").await),
        ToolKind::GetProcesses => ToolResult::Json(handle_get_slice(host, port, "processes").await),
        ToolKind::KillProcess => {
            let pid = args["id"].as_u64().unwrap_or(0) as u32;
            ToolResult::Text(handle_kill_process(host, port, pid).await)
        }
        ToolKind::SavePlace => {
            let out = args["out"].as_str().map(String::from);
            ToolResult::Text(handle_save_place(host, port, out).await)
        }
        ToolKind::Luau { script, target } => {
            ToolResult::Text(handle_luau_tool(host, port, script, target, args).await)
        }
        ToolKind::StudioProxy { original_name } => {
            let mut guard = studio_mcp.lock().await;
            match guard.as_mut() {
                Some(mcp) => match mcp.call_tool_raw(original_name, args).await {
                    Ok(raw) => ToolResult::Raw(raw),
                    Err(e) => ToolResult::Text(Err(e)),
                },
                None => ToolResult::Text(Err("StudioMCP not connected".into())),
            }
        }
    }
}

// --- Main ---

pub async fn main(host: &str, port: u16) -> Result<()> {
    eprintln!("[rodeo mcp] starting, host={host} port={port}");

    let mut tools = build_builtin_tools();

    eprintln!("[rodeo mcp] discovering luau tools...");
    tools.extend(build_luau_tools(discover_luau_tools()));

    let mut studio_mcp_client: Option<StudioMcpClient> = None;
    eprintln!("[rodeo mcp] connecting to StudioMCP...");
    if let Err(e) = add_studio_proxy_tools(&mut tools, &mut studio_mcp_client).await {
        eprintln!("[rodeo mcp] StudioMCP proxy unavailable: {e}");
    } else {
        eprintln!("[rodeo mcp] StudioMCP proxy tools added");
    }

    let studio_mcp = Arc::new(Mutex::new(studio_mcp_client));

    eprintln!("[rodeo mcp] {} tools registered", tools.len());

    let stdin = std::io::stdin();
    let mut stdout = std::io::stdout();

    for line in stdin.lock().lines() {
        let line = line?;
        if line.is_empty() { continue; }
        let msg: serde_json::Value = serde_json::from_str(&line)?;
        let method = msg["method"].as_str().unwrap_or("");
        let id = &msg["id"];

        match method {
            "initialize" => {
                let resp = serde_json::json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": { "tools": {} },
                        "serverInfo": { "name": "rodeo", "version": env!("CARGO_PKG_VERSION") },
                        "instructions": SERVER_INSTRUCTIONS
                    }
                });
                writeln!(stdout, "{}", serde_json::to_string(&resp)?)?;
                stdout.flush()?;
            }
            "tools/list" => {
                let tool_list: Vec<serde_json::Value> = tools.iter().map(|t| {
                    let mut entry = serde_json::json!({
                        "name": t.name,
                        "description": t.description,
                        "inputSchema": t.input_schema
                    });
                    if let Some(output_schema) = &t.output_schema {
                        entry["outputSchema"] = output_schema.clone();
                    }
                    if let Some(annotations) = &t.annotations {
                        entry["annotations"] = annotations.clone();
                    }
                    entry
                }).collect();

                let resp = serde_json::json!({
                    "jsonrpc": "2.0",
                    "id": id,
                    "result": { "tools": tool_list }
                });
                writeln!(stdout, "{}", serde_json::to_string(&resp)?)?;
                stdout.flush()?;
            }
            "tools/call" => {
                let tool_name = msg["params"]["name"].as_str().unwrap_or("");
                let args = &msg["params"]["arguments"];

                let tool_result = if let Some(tool) = tools.iter().find(|t| t.name == tool_name) {
                    execute_tool(tool, args, host, port, &studio_mcp).await
                } else {
                    ToolResult::Text(Err(format!("Unknown tool: {tool_name}")))
                };

                let resp = match tool_result {
                    ToolResult::Raw(raw) => serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": id,
                        "result": raw
                    }),
                    ToolResult::Json(data) => serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": id,
                        "result": { "content": [{ "type": "text", "text": serde_json::to_string_pretty(&data).unwrap_or_default() }] }
                    }),
                    ToolResult::Text(Ok(text)) => serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": id,
                        "result": { "content": [{ "type": "text", "text": text }] }
                    }),
                    ToolResult::Text(Err(e)) => serde_json::json!({
                        "jsonrpc": "2.0",
                        "id": id,
                        "result": { "content": [{ "type": "text", "text": e }], "isError": true }
                    }),
                    ToolResult::Structured { text, structured, is_error } => {
                        let mut result = serde_json::json!({
                            "content": [{ "type": "text", "text": text }],
                            "structuredContent": structured
                        });
                        if is_error {
                            result["isError"] = serde_json::Value::Bool(true);
                        }
                        serde_json::json!({
                            "jsonrpc": "2.0",
                            "id": id,
                            "result": result
                        })
                    }
                };
                writeln!(stdout, "{}", serde_json::to_string(&resp)?)?;
                stdout.flush()?;
            }
            "notifications/initialized" => {
                // Client acknowledges initialization — no response needed
            }
            _ => {}
        }
    }
    Ok(())
}

// --- Tool handlers ---

async fn handle_run_code(host: &str, port: u16, args: &serde_json::Value) -> RunCodeOutput {
    let fail = |msg: String| RunCodeOutput {
        stdout: String::new(),
        return_value: None,
        exit_code: 1,
        error: Some(msg),
    };

    let code = args["code"].as_str().unwrap_or("").to_string();
    let target = args["target"].as_str().unwrap_or("").to_string();
    let vm_id = args["vm"].as_str().map(String::from);
    let job = args["job"].as_str().map(String::from);
    let script_args: Vec<String> = args["args"]
        .as_array()
        .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default();
    let cache_requires = args["cache_requires"].as_bool().unwrap_or(false);
    let sourcemap = args["sourcemap"].as_str().map(String::from);
    let instance_path = args["instance_path"].as_str().map(String::from);
    let profile_dir = args["profile_dir"].as_str().map(std::path::PathBuf::from);
    let profile = args["profile"].as_bool().unwrap_or(false) || profile_dir.is_some();
    let logs_dir = args["logs_dir"].as_str().map(std::path::PathBuf::from);
    let logs = args["logs"].as_bool().unwrap_or(false) || logs_dir.is_some();

    if !target.is_empty() {
        if let Err(e) = crate::shared::target::parse(&target) {
            return fail(e.to_string());
        }
    }

    let return_file = std::env::temp_dir()
        .join(format!("rodeo-mcp-{}.json", uuid::Uuid::new_v4()))
        .to_string_lossy().to_string();
    let output_file = args["output"].as_str()
        .map(String::from)
        .unwrap_or_else(|| std::env::temp_dir()
            .join(format!("rodeo-mcp-out-{}.txt", uuid::Uuid::new_v4()))
            .to_string_lossy().to_string());
    let custom_return = args["return_file"].as_str().map(String::from);

    let request = RunRequest {
        script: {
            let output = std::process::Command::new(std::env::current_exe().unwrap())
                .args(["__process_source", "--source", &code])
                .output()
                .expect("failed to run __process_source");
            if !output.status.success() {
                code.clone() // fallback to raw source on error
            } else {
                serde_json::from_slice::<process_source::ProcessedSource>(&output.stdout)
                    .map(|p| p.script)
                    .unwrap_or_else(|_| code.clone())
            }
        },
        target,
        vm_id,
        job,
        log_filter: proto::LogFilter {
                enable_warn: true,
                enable_error: true,
                enable_info: true,
                enable_output: true,
                enable_logs: true,
                ..Default::default()
            },
        cache_requires,
        script_args,
        return_file: Some(custom_return.as_ref().unwrap_or(&return_file).clone()),
        show_return: false,
        output_file: Some(output_file.clone()),
        verbose: false,
        instance_path,
        script_path: sourcemap,
        process_name: None,
        profile,
        profile_dir,
        logs,
        logs_dir,
    };

    let result = match cli_run::run_piped(host, port, request).await {
        Ok(r) => r,
        Err(e) => return fail(e.to_string()),
    };

    let mut stdout = String::new();
    let out_path = &output_file;
    if let Ok(out) = std::fs::read_to_string(out_path) {
        if !out.is_empty() { stdout.push_str(&out); }
        if args["output"].is_null() { let _ = std::fs::remove_file(out_path); }
    }

    let ret_path = custom_return.as_ref().unwrap_or(&return_file);
    let return_value = match std::fs::read_to_string(ret_path) {
        Ok(ret) if !ret.is_empty() => Some(ret),
        _ => None,
    };
    if custom_return.is_none() { let _ = std::fs::remove_file(ret_path); }

    let error = if result.exit_code != 0 {
        Some(if stdout.is_empty() {
            format!("Execution failed (exit code {})", result.exit_code)
        } else {
            stdout.clone()
        })
    } else {
        None
    };

    RunCodeOutput { stdout, return_value, exit_code: result.exit_code, error }
}

async fn handle_get_state(host: &str, port: u16) -> serde_json::Value {
    let url: http::Uri = match format!("http://{host}:{port}").parse() {
        Ok(u) => u,
        Err(e) => return serde_json::json!({"error": format!("invalid URL: {e}")}),
    };
    let http_client = connectrpc::client::HttpClient::plaintext();
    let config = connectrpc::client::ClientConfig::new(url);
    let client = proto::MasterServiceClient::new(http_client, config);
    match client.get_state(proto::GetStateRequest::default()).await {
        Ok(resp) => serde_json::to_value(resp.into_owned()).unwrap_or(serde_json::json!({"error": "serialize error"})),
        Err(e) => serde_json::json!({"error": e.to_string()}),
    }
}

async fn handle_get_slice(host: &str, port: u16, key: &str) -> serde_json::Value {
    let state = handle_get_state(host, port).await;
    state.get(key).cloned().unwrap_or(serde_json::json!([]))
}

async fn handle_kill_process(host: &str, port: u16, id: u32) -> Result<String, String> {
    RodeoClient::connect(host, port).map_err(|e| e.to_string())?.kill(id).await.map_err(|e| e.to_string())?;
    Ok(format!("Killed process #{id}"))
}

async fn handle_save_place(host: &str, port: u16, out: Option<String>) -> Result<String, String> {
    let result = RodeoClient::connect(host, port).map_err(|e| e.to_string())?.save_default().await.map_err(|e| e.to_string())?;
    let mut msg = "Place saved".to_string();
    if let Some(out_path) = out {
        if let Some(src_path) = result.path {
            std::fs::copy(&src_path, &out_path).map_err(|e| format!("Failed to copy: {e}"))?;
            msg = format!("Place saved and copied to {out_path}");
        }
    }
    Ok(msg)
}

/// Convert MCP tool arguments (a JSON object) into argparse-style argv:
///   `{ "cframe": "...", "fov": 90, "verbose": true }`
///     → `["--cframe", "...", "--fov", "90", "--verbose"]`
/// Booleans become bare flags (false → omitted); null/missing values are dropped;
/// other scalars are stringified.
fn json_args_to_argv(args: &serde_json::Value) -> Vec<String> {
    let Some(obj) = args.as_object() else { return vec![]; };
    let mut argv = Vec::with_capacity(obj.len() * 2);
    for (key, val) in obj {
        if val.is_null() { continue; }
        if let Some(b) = val.as_bool() {
            if b { argv.push(format!("--{key}")); }
            continue;
        }
        argv.push(format!("--{key}"));
        argv.push(match val {
            serde_json::Value::String(s) => s.clone(),
            other => other.to_string(),
        });
    }
    argv
}

async fn handle_luau_tool(host: &str, port: u16, script: &str, target: &str, args: &serde_json::Value) -> Result<String, String> {
    let return_file = std::env::temp_dir()
        .join(format!("rodeo-mcp-{}.json", uuid::Uuid::new_v4()))
        .to_string_lossy().to_string();
    let output_file = std::env::temp_dir()
        .join(format!("rodeo-mcp-out-{}.txt", uuid::Uuid::new_v4()))
        .to_string_lossy().to_string();

    let request = RunRequest {
        script: script.to_string(),
        target: target.to_string(),
        vm_id: None, job: None,
        log_filter: proto::LogFilter {
                enable_warn: true,
                enable_error: true,
                enable_info: true,
                enable_output: true,
                enable_logs: true,
                ..Default::default()
            },
        cache_requires: false,
        script_args: json_args_to_argv(args),
        return_file: Some(return_file.clone()),
        show_return: false,
        output_file: Some(output_file.clone()),
        verbose: false,
        instance_path: None, script_path: None, process_name: None,
        profile: false, profile_dir: None,
        logs: false, logs_dir: None,
    };

    let result = cli_run::run_piped(host, port, request).await.map_err(|e| e.to_string())?;

    let mut output = String::new();
    if let Ok(out) = std::fs::read_to_string(&output_file) {
        if !out.is_empty() { output.push_str(&out); }
        let _ = std::fs::remove_file(&output_file);
    }
    if let Ok(ret) = std::fs::read_to_string(&return_file) {
        if !ret.is_empty() {
            if !output.is_empty() { output.push('\n'); }
            output.push_str("[return] ");
            output.push_str(&ret);
        }
        let _ = std::fs::remove_file(&return_file);
    }

    if result.exit_code != 0 {
        if output.is_empty() { output = format!("Failed (exit code {})", result.exit_code); }
        return Err(output);
    }
    if output.is_empty() { output = "OK".to_string(); }
    Ok(output)
}
