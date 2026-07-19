use anyhow::Result;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

use crate::cli_run::{self, RunRequest};
use crate::commands::process_source;
use rbx_control::studio::mcp_client::StudioMcpClient;
use rodeo_client::RodeoClient;
use rodeo_proto as proto;

use rmcp::handler::server::router::tool::{ToolRoute, ToolRouter};
use rmcp::handler::server::tool::ToolCallContext;
use rmcp::handler::server::wrapper::Parameters;
use rmcp::model::{
    CallToolResult, Content, JsonObject, ServerCapabilities, ServerInfo, Tool, ToolAnnotations,
};
use rmcp::transport::stdio;
use rmcp::{ServerHandler, ServiceExt, tool, tool_handler, tool_router};

const SERVER_INSTRUCTIONS: &str = "\
rodeo executes Luau code inside Roblox Studio via WebSocket.

Run routing (orthogonal args):
- mode: edit | run | test | play — the sole driver of studio transitions; defaults to edit and is NEVER inferred from context/dom. A server/client run must set mode (e.g. mode=run context=server, mode=test context=client).
- context: the identity level the code runs at — plugin | server (server-runtime identity) | client (client-runtime identity) | elevated (command bar). Each context is an independent Luau VM on the DOM.
- dom: edit | server | client — which DataModel to run on (usually inferred; `edit` targets the edit DOM even while a session runs). The DOM is the communication boundary: contexts on the same DOM share instances (BindableEvents), different DOMs talk via RemoteEvents.
Examples: no args = edit plugin; mode=run context=server = server identity in run mode; mode=test context=client = client identity in a play test; context=elevated = command-bar identity in edit.

Direct targeting:
- dom_id: pin to one DOM by id (from get_state); studio_id: scope to one studio

Launch:
- launch_studio: open a standalone Studio (place = empty/ID/file path), optionally with profiling; stays alive for later run_code calls
- run_code place: launch Studio inline when running code (empty = new place, number = place ID, string = file path)

Return values: Scripts can return values. Use run_code to both query data and make changes.
Use get_state to discover available DOMs, studios, and processes.
";

// --- Luau tool discovery ---

struct LuauTool {
    name: String,
    description: String,
    script: String,
    route: crate::shared::target::RouteSpec,
    input_schema: Option<serde_json::Value>,
    annotations: Option<serde_json::Value>,
}

/// Read a routing spec from `@rodeo run` flag tokens
/// (`--mode`/`--dom`/`--context`). Unknown/invalid values
/// yield an empty spec (defaults apply).
fn route_from_flag_tokens(inline: &str) -> crate::shared::target::RouteSpec {
    let toks: Vec<&str> = inline.split_whitespace().collect();
    let val = |flag: &str| {
        toks.iter().position(|t| *t == flag).and_then(|i| toks.get(i + 1)).copied()
    };
    crate::shared::target::RouteSpec::from_strings(
        val("--mode"),
        val("--dom"),
        val("--context"),
    )
    .unwrap_or_default()
}

/// Parse the leading `--[[ ... ]]` header of a Luau tool source.
///
/// Supported directives:
///   `@rodeo run --mode <m> --context <c> …` — inline; sets the run route
///   `@rodeo schema` — claims subsequent non-`@rodeo` lines as JSON inputSchema
///   `@rodeo annotations` — claims subsequent non-`@rodeo` lines as JSON annotations
///
/// All other non-`@rodeo` lines are concatenated into the tool description.
/// `schema` / `annotations` consume lines until the next `@rodeo` directive or
/// the end of the block, so place them last in the header.
fn parse_luau_header(
    source: &str,
) -> (
    String,
    crate::shared::target::RouteSpec,
    Option<serde_json::Value>,
    Option<serde_json::Value>,
) {
    let mut description = String::new();
    let mut route = crate::shared::target::RouteSpec::default();
    let mut schema: Option<serde_json::Value> = None;
    let mut annotations: Option<serde_json::Value> = None;

    let Some(start) = source.find("--[[") else {
        return (description, route, schema, annotations);
    };
    let block_start = start + 4;
    let Some(rel_end) = source[block_start..].find("]]") else {
        return (description, route, schema, annotations);
    };
    let block = &source[block_start..block_start + rel_end];

    #[derive(PartialEq)]
    enum Section {
        Description,
        Schema,
        Annotations,
    }
    let mut current = Section::Description;
    let mut buffer = String::new();

    let flush = |sec: &Section,
                 buf: &str,
                 schema: &mut Option<serde_json::Value>,
                 annotations: &mut Option<serde_json::Value>| {
        let trimmed = buf.trim();
        if trimmed.is_empty() {
            return;
        }
        match sec {
            Section::Schema => {
                *schema = serde_json::from_str(trimmed).ok();
            }
            Section::Annotations => {
                *annotations = serde_json::from_str(trimmed).ok();
            }
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
                    route = route_from_flag_tokens(inline);
                    current = Section::Description;
                }
                "schema" => {
                    current = Section::Schema;
                    if !inline.is_empty() {
                        buffer.push_str(inline);
                    }
                }
                "annotations" => {
                    current = Section::Annotations;
                    if !inline.is_empty() {
                        buffer.push_str(inline);
                    }
                }
                _ => {
                    current = Section::Description;
                }
            }
        } else if current == Section::Description {
            if !trimmed.is_empty() {
                if !description.is_empty() {
                    description.push(' ');
                }
                description.push_str(trimmed);
            }
        } else {
            if !buffer.is_empty() {
                buffer.push('\n');
            }
            buffer.push_str(line);
        }
    }
    flush(&current, &buffer, &mut schema, &mut annotations);

    (description, route, schema, annotations)
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
        let name = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_string();
        let Ok(source) = std::fs::read_to_string(&path) else {
            continue;
        };

        let (description, route, input_schema, annotations) = parse_luau_header(&source);

        tools.push(LuauTool {
            name,
            description,
            script: source,
            route,
            input_schema,
            annotations,
        });
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
    defaults.insert(
        "execute_luau".into(),
        RemapEntry {
            exclude: true,
            ..Default::default()
        },
    );
    defaults.insert(
        "start_stop_play".into(),
        RemapEntry {
            exclude: true,
            ..Default::default()
        },
    );
    defaults
}

// --- Schema helpers ---

fn obj_from_value(v: serde_json::Value) -> JsonObject {
    match v {
        serde_json::Value::Object(m) => m,
        _ => JsonObject::new(),
    }
}

fn obj_arc(v: serde_json::Value) -> Arc<JsonObject> {
    Arc::new(obj_from_value(v))
}

fn annotations_from_json(v: &serde_json::Value) -> ToolAnnotations {
    let bool_at = |k: &str| v.get(k).and_then(|x| x.as_bool());
    let title_at = |k: &str| v.get(k).and_then(|x| x.as_str()).map(String::from);
    ToolAnnotations::from_raw(
        title_at("title"),
        bool_at("readOnlyHint"),
        bool_at("destructiveHint"),
        bool_at("idempotentHint"),
        bool_at("openWorldHint"),
    )
}

fn run_code_input_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({
        "type": "object",
        "properties": {
            "code": { "type": "string", "description": "Luau code to execute. Can return a value." },
            "mode": {
                "type": "string",
                "enum": ["edit", "run", "test", "play"],
                "description": "Studio mode to run in (auto-transitions Studio). Defaults to edit; never inferred from context/dom, so a server/client run must set mode explicitly (e.g. mode=run context=server)."
            },
            "dom": {
                "type": "string",
                "enum": ["edit", "server", "client"],
                "description": "Which DOM receives the script. Usually inferred from context/mode. `edit` targets the edit DOM even while a test/play session runs."
            },
            "context": {
                "type": "string",
                "enum": ["plugin", "server", "client", "elevated"],
                "description": "Identity level the code runs at (its own Luau VM on the DOM): plugin, server (server-runtime identity), client (client-runtime identity), or elevated (command-bar identity, for privileged Roblox APIs like DebuggerManager). NOT a script class — a ModuleScript runs at whatever context requires it."
            },
            "dom_id": { "type": "string", "description": "Pin the run to one DOM by id (from get_state; bypasses routing). Only context may accompany it." },
            "studio_id": { "type": "string", "description": "Scope routing to one studio by id (from get_state)." },
            "place": { "type": "string", "description": "Launch Studio: empty = new place, number = place ID, path = .rbxl file" },
            "args": { "type": "array", "items": { "type": "string" }, "description": "Script arguments (accessible via require('@rodeo/process').args)" },
            "cache_requires": { "type": "boolean", "description": "Use cached module state" },
            "output": { "type": "string", "description": "Write output to file path" },
            "return_file": { "type": "string", "description": "Write return value to file path" },
            "detached": { "type": "boolean", "description": "Keep Studio alive after execution" },
            "sourcemap": { "type": "string", "description": "Path to sourcemap.json for require resolution" },
            "instance_path": { "type": "string", "description": "Instance path for the script" },
            "profile": { "type": "boolean", "description": "Capture a microprofiler dump for this run" },
            "profile_dir": { "type": "string", "description": "Directory to write the profile dump into (implies profile=true)" }
        },
        "required": ["code"]
    }))
}

fn run_code_output_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({
        "type": "object",
        "properties": {
            "stdout": { "type": "string", "description": "Combined stdout/stderr from the script run." },
            "return_value": { "type": ["string", "null"], "description": "Raw JSON-encoded return value. Null if the script returned nothing, or if a return_file captured the value instead." },
            "exit_code": { "type": "integer", "description": "0 on success, non-zero on script error or runtime failure." },
            "error": { "type": ["string", "null"], "description": "Failure message when exit_code is non-zero." }
        },
        "required": ["stdout", "exit_code"]
    }))
}

fn empty_object_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({ "type": "object" }))
}

fn kill_process_input_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({
        "type": "object",
        "properties": {
            "id": { "type": "string", "description": "Run ID (from get_processes)" }
        },
        "required": ["id"]
    }))
}

fn save_place_input_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({
        "type": "object",
        "properties": {
            "out": { "type": "string", "description": "Copy saved file to this path" }
        }
    }))
}

fn launch_studio_input_schema() -> Arc<JsonObject> {
    obj_arc(serde_json::json!({
        "type": "object",
        "properties": {
            "place": { "type": "string", "description": "What to open: empty = new place, a number = published place ID, a path = local .rbxl/.rbxlx file" },
            "universe_id": { "type": "integer", "description": "Universe ID to resolve a published place ID against (optional)" },
            "profile": { "type": "boolean", "description": "Enable microprofiler auto-capture on the launched Studio, so later run_code calls with profile_dir collect dumps" },
            "detached": { "type": "boolean", "description": "Keep Studio running even if the rodeo server stops (default: false, tied to the server's lifetime). Studio persists across run_code calls either way" },
            "focus": { "type": "boolean", "description": "Bring Studio to the foreground (default: launch in the background)" },
            "show_widgets": { "type": "string", "description": "Allow-list of Studio dock widgets to keep visible; everything else (panels, ribbon, command bar) is hidden. 'none' hides all; a comma list keeps those (aliases: output, explorer, properties, editor, toolbox, assistant, ribbon, commandbar; or a raw panel ID)" }
        }
    }))
}

// --- Typed parameter structs for #[tool] fns. ---
// Only `Deserialize` is required — input schemas are passed explicitly to the
// macro via `input_schema = ...` to preserve our hand-crafted JSON exactly.
// `run_code` accepts the whole arg object as a raw `Value` so the existing
// `handle_run_code` body (which reads many optional keys) keeps working unchanged.

#[derive(Debug, serde::Deserialize)]
struct KillProcessArgs {
    #[serde(default)]
    id: String,
}

#[derive(Debug, serde::Deserialize, Default)]
struct SavePlaceArgs {
    #[serde(default)]
    out: Option<String>,
}

#[derive(Debug, serde::Deserialize, Default)]
struct LaunchStudioArgs {
    #[serde(default)]
    place: Option<String>,
    #[serde(default)]
    universe_id: Option<u64>,
    #[serde(default)]
    profile: bool,
    #[serde(default)]
    detached: bool,
    #[serde(default)]
    focus: bool,
    #[serde(default)]
    show_widgets: Option<String>,
}

// --- Server state ---

#[derive(Clone)]
struct RodeoServer {
    host: Arc<String>,
    port: u16,
    studio_mcp: Arc<Mutex<Option<StudioMcpClient>>>,
    tool_router: ToolRouter<Self>,
}

// --- Helpers used by handlers ---

/// Race a future against the request's cancellation token. On cancel, returns
/// an isError CallToolResult with the standard text — handlers that don't have
/// side effects can early-out via this helper.
async fn text_or_cancel<F>(ct: &CancellationToken, fut: F) -> CallToolResult
where
    F: std::future::Future<Output = Result<String, String>>,
{
    tokio::select! {
        biased;
        _ = ct.cancelled() => CallToolResult::error(vec![Content::text("cancelled by client")]),
        res = fut => match res {
            Ok(text) => CallToolResult::success(vec![Content::text(text)]),
            Err(e) => CallToolResult::error(vec![Content::text(e)]),
        },
    }
}

async fn json_or_cancel<F>(ct: &CancellationToken, fut: F) -> CallToolResult
where
    F: std::future::Future<Output = serde_json::Value>,
{
    tokio::select! {
        biased;
        _ = ct.cancelled() => CallToolResult::error(vec![Content::text("cancelled by client")]),
        value = fut => {
            let text = serde_json::to_string_pretty(&value).unwrap_or_default();
            CallToolResult::success(vec![Content::text(text)])
        },
    }
}

// --- Static tools (macro-registered) ---

#[tool_router(router = tool_router)]
impl RodeoServer {
    #[tool(
        description = "Execute Luau code in a Roblox Studio DOM, routed by mode / \
            context / dom (all optional). If no live DOM matches, Studio \
            transitions into the requested mode first (e.g. entering play test) — \
            this mutates Studio state and may take several seconds. Use \
            `context: \"elevated\"` to run at command-bar identity instead of \
            plugin; required for privileged Roblox APIs like `DebuggerManager`. \
            Use `get_state` to see what DOMs are currently alive.",
        input_schema = run_code_input_schema(),
        output_schema = run_code_output_schema(),
        annotations(destructive_hint = true, idempotent_hint = false, open_world_hint = true),
    )]
    async fn run_code(
        &self,
        Parameters(args): Parameters<serde_json::Value>,
        ct: CancellationToken,
    ) -> CallToolResult {
        handle_run_code_with_cancel(&self.host, self.port, args, &ct).await
    }

    #[tool(
        description = "Get the full canonical rodeo state: studios, backends, DOMs, and processes.",
        input_schema = empty_object_schema(),
        annotations(read_only_hint = true, idempotent_hint = true),
    )]
    async fn get_state(&self, ct: CancellationToken) -> CallToolResult {
        json_or_cancel(&ct, handle_get_state(&self.host, self.port)).await
    }

    #[tool(
        description = "List rodeo processes (queued, running, completed) with their run IDs and state. Use a run ID with kill_process.",
        input_schema = empty_object_schema(),
        annotations(read_only_hint = true, idempotent_hint = true),
    )]
    async fn get_processes(&self, ct: CancellationToken) -> CallToolResult {
        json_or_cancel(&ct, handle_get_slice(&self.host, self.port, "processes")).await
    }

    #[tool(
        description = "Kill a running process by run ID.",
        input_schema = kill_process_input_schema(),
        annotations(destructive_hint = true, idempotent_hint = true),
    )]
    async fn kill_process(
        &self,
        Parameters(args): Parameters<KillProcessArgs>,
        ct: CancellationToken,
    ) -> CallToolResult {
        text_or_cancel(&ct, handle_kill_process(&self.host, self.port, &args.id)).await
    }

    #[tool(
        description = "Save the Studio place file.",
        input_schema = save_place_input_schema(),
        annotations(destructive_hint = false, idempotent_hint = true),
    )]
    async fn save_place(
        &self,
        Parameters(args): Parameters<SavePlaceArgs>,
        ct: CancellationToken,
    ) -> CallToolResult {
        text_or_cancel(&ct, handle_save_place(&self.host, self.port, args.out)).await
    }

    #[tool(
        description = "Launch a Roblox Studio instance and block until it connects, without running any \
            code. The Studio stays connected to the server so subsequent run_code calls can target it. \
            Pass `place` to open a published place ID or a local .rbxl file; omit it for a new empty \
            place. Set `profile` to enable microprofiler capture for later profiling runs, and \
            `detached` to keep Studio running even after the server stops.",
        input_schema = launch_studio_input_schema(),
        annotations(destructive_hint = false, idempotent_hint = false, open_world_hint = true),
    )]
    async fn launch_studio(
        &self,
        Parameters(args): Parameters<LaunchStudioArgs>,
        ct: CancellationToken,
    ) -> CallToolResult {
        text_or_cancel(&ct, handle_launch_studio(&self.host, self.port, args)).await
    }
}

// --- ServerHandler impl (macro-driven) ---

#[tool_handler(router = self.tool_router)]
impl ServerHandler for RodeoServer {
    fn get_info(&self) -> ServerInfo {
        ServerInfo::new(ServerCapabilities::builder().enable_tools().build())
            .with_server_info(rmcp::model::Implementation::new(
                "rodeo",
                env!("CARGO_PKG_VERSION"),
            ))
            .with_instructions(SERVER_INSTRUCTIONS.to_string())
    }
}

impl RodeoServer {
    fn new(host: String, port: u16, studio_mcp: Arc<Mutex<Option<StudioMcpClient>>>) -> Self {
        Self {
            host: Arc::new(host),
            port,
            studio_mcp,
            tool_router: Self::tool_router(),
        }
    }

    fn register_luau_tool(&mut self, lt: LuauTool) {
        let input_schema = lt
            .input_schema
            .unwrap_or_else(|| serde_json::json!({ "type": "object" }));
        let mut tool = Tool::new_with_raw(
            lt.name,
            if lt.description.is_empty() {
                None
            } else {
                Some(lt.description.into())
            },
            obj_arc(input_schema),
        );
        if let Some(ann) = lt.annotations.as_ref() {
            tool = tool.with_annotations(annotations_from_json(ann));
        }

        let route = lt.route;
        let script = lt.script.clone();
        self.tool_router.add_route(ToolRoute::new_dyn(tool, move |tcc: ToolCallContext<'_, RodeoServer>| {
            let route = route;
            let script = script.clone();
            Box::pin(async move {
                let ct = tcc.request_context.ct.clone();
                let svc = tcc.service;
                let args = serde_json::Value::Object(tcc.arguments.unwrap_or_default());
                Ok(text_or_cancel(
                    &ct,
                    handle_luau_tool(&svc.host, svc.port, script, route, args),
                )
                .await)
            })
        }));
    }

    fn register_studio_proxy_tool(
        &mut self,
        tool_name: String,
        description: String,
        input_schema: serde_json::Value,
        output_schema: Option<serde_json::Value>,
        annotations: Option<serde_json::Value>,
        original_name: String,
    ) {
        let mut tool = Tool::new_with_raw(
            tool_name,
            if description.is_empty() {
                None
            } else {
                Some(description.into())
            },
            obj_arc(input_schema),
        );
        if let Some(out_schema) = output_schema {
            tool = tool.with_raw_output_schema(obj_arc(out_schema));
        }
        if let Some(ann) = annotations.as_ref() {
            tool = tool.with_annotations(annotations_from_json(ann));
        }

        let original_name = original_name.clone();
        self.tool_router.add_route(ToolRoute::new_dyn(tool, move |tcc: ToolCallContext<'_, RodeoServer>| {
            let original_name = original_name.clone();
            Box::pin(async move {
                let ct = tcc.request_context.ct.clone();
                let svc = tcc.service;
                let args = serde_json::Value::Object(tcc.arguments.unwrap_or_default());

                tokio::select! {
                    biased;
                    _ = ct.cancelled() => {
                        Ok(CallToolResult::error(vec![Content::text("cancelled by client")]))
                    }
                    result = async {
                        let mut guard = svc.studio_mcp.lock().await;
                        match guard.as_mut() {
                            Some(mcp) => mcp.call_tool_raw(&original_name, &args).await,
                            None => Err("StudioMCP not connected".to_string()),
                        }
                    } => match result {
                        Ok(raw) => Ok(call_tool_result_from_raw(raw)),
                        Err(e) => Ok(CallToolResult::error(vec![Content::text(e)])),
                    }
                }
            })
        }));
    }
}

/// Convert StudioMCP's raw JSON-RPC `result` shape into a `CallToolResult`.
/// The upstream server already returns MCP-shaped fields (content, structuredContent,
/// isError, _meta) so we deserialize via serde directly. Falls back to a text wrapper
/// if the shape is unexpected.
fn call_tool_result_from_raw(raw: serde_json::Value) -> CallToolResult {
    match serde_json::from_value::<CallToolResult>(raw.clone()) {
        Ok(r) => r,
        Err(_) => {
            // Fallback: wrap the raw value as a text block so callers still get something
            CallToolResult::success(vec![Content::text(
                serde_json::to_string(&raw).unwrap_or_default(),
            )])
        }
    }
}

// --- StudioMCP proxy setup ---

async fn add_studio_proxy_tools(
    server: &mut RodeoServer,
    studio_mcp: &mut Option<StudioMcpClient>,
) -> Result<(), String> {
    let remap = load_remap_config();
    let mut mcp_client = StudioMcpClient::new("rodeo").await?;

    let mcp_tools = {
        let mut attempts = 0;
        loop {
            let list = mcp_client.list_tools().await?;
            if !list.is_empty() {
                break list;
            }
            attempts += 1;
            if attempts > 10 {
                return Err(
                    "StudioMCP has no tools. Enable MCP Server in Studio AI Assistant settings."
                        .into(),
                );
            }
            tokio::time::sleep(std::time::Duration::from_secs(1)).await;
        }
    };

    let existing: std::collections::HashSet<String> = server
        .tool_router
        .list_all()
        .iter()
        .map(|t| t.name.to_string())
        .collect();

    for tool_value in mcp_tools {
        let original_name = tool_value["name"].as_str().unwrap_or("").to_string();
        if let Some(entry) = remap.get(&original_name) {
            if entry.exclude {
                continue;
            }
        }
        let tool_name = remap
            .get(&original_name)
            .and_then(|e| e.name.clone())
            .unwrap_or_else(|| original_name.clone());
        if existing.contains(&tool_name) {
            continue;
        }

        let description = remap
            .get(&original_name)
            .and_then(|e| e.description.clone())
            .or_else(|| tool_value["description"].as_str().map(String::from))
            .unwrap_or_default();

        server.register_studio_proxy_tool(
            tool_name,
            description,
            tool_value["inputSchema"].clone(),
            tool_value.get("outputSchema").cloned(),
            tool_value.get("annotations").cloned(),
            original_name,
        );
    }

    *studio_mcp = Some(mcp_client);
    Ok(())
}

// --- Main ---

pub async fn main(host: &str, port: u16) -> Result<()> {
    eprintln!("[rodeo mcp] starting, host={host} port={port}");

    // Ensure a serve backs the serve-dependent tools, so `rodeo mcp` works
    // without a separately-launched `rodeo serve`. Reuse a healthy one;
    // otherwise start one we own for this MCP session (its handle is held in
    // `_serve_handle` until `main` returns, then torn down). Localhost only —
    // a remote host must already be serving.
    let _serve_handle = if host == "localhost" || host == "127.0.0.1" {
        if RodeoClient::connect(host, port)?.is_healthy().await {
            eprintln!("[rodeo mcp] reusing serve on {host}:{port}");
            None
        } else {
            eprintln!("[rodeo mcp] no serve on {port}; starting one");
            Some(super::serve::start_full_serve(port).await?)
        }
    } else {
        None
    };

    let studio_mcp_holder: Arc<Mutex<Option<StudioMcpClient>>> = Arc::new(Mutex::new(None));
    let mut server = RodeoServer::new(host.to_string(), port, studio_mcp_holder.clone());

    eprintln!("[rodeo mcp] discovering luau tools...");
    for lt in discover_luau_tools() {
        server.register_luau_tool(lt);
    }

    let mut studio_mcp_client: Option<StudioMcpClient> = None;
    eprintln!("[rodeo mcp] connecting to StudioMCP...");
    // Bound StudioMCP setup so an unreachable/unhealthy MCP doesn't block the
    // server's `initialize` response. The 7 static tools + Luau tools are
    // already registered; StudioMCP proxy tools are best-effort.
    let setup = tokio::time::timeout(
        std::time::Duration::from_millis(1500),
        add_studio_proxy_tools(&mut server, &mut studio_mcp_client),
    )
    .await;
    match setup {
        Ok(Ok(())) => eprintln!("[rodeo mcp] StudioMCP proxy tools added"),
        Ok(Err(e)) => eprintln!("[rodeo mcp] StudioMCP proxy unavailable: {e}"),
        Err(_) => eprintln!("[rodeo mcp] StudioMCP proxy setup timed out; skipping"),
    }

    {
        let mut guard = studio_mcp_holder.lock().await;
        *guard = studio_mcp_client;
    }

    eprintln!(
        "[rodeo mcp] {} tools registered",
        server.tool_router.list_all().len()
    );

    let service = server.serve(stdio()).await?;
    service.waiting().await?;
    Ok(())
}

// --- Tool handlers ---

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
        if !self.stdout.is_empty() {
            s.push_str(&self.stdout);
        }
        if let Some(ret) = &self.return_value {
            if !ret.is_empty() {
                if !s.is_empty() {
                    s.push('\n');
                }
                s.push_str("[return] ");
                s.push_str(ret);
            }
        }
        if let Some(err) = &self.error {
            if s.is_empty() {
                s = err.clone();
            }
        }
        if s.is_empty() {
            s = "OK".to_string();
        }
        s
    }

    fn into_call_tool_result(self) -> CallToolResult {
        let is_error = self.exit_code != 0;
        let text = self.to_text();
        let structured = self.to_structured();
        let mut result = CallToolResult::success(vec![Content::text(text)]);
        result.structured_content = Some(structured);
        if is_error {
            result.is_error = Some(true);
        }
        result
    }
}

/// Race a run_code execution against the request CT. On cancel, we send a
/// best-effort kill via the master service using the run id captured from the
/// Created event, and short-circuit to an isError result.
async fn handle_run_code_with_cancel(
    host: &str,
    port: u16,
    args: serde_json::Value,
    ct: &CancellationToken,
) -> CallToolResult {
    let host_owned = host.to_string();
    let (created_tx, mut created_rx) = tokio::sync::oneshot::channel::<String>();

    let run_fut = async move {
        handle_run_code(&host_owned, port, &args, Some(created_tx)).await
    };

    tokio::select! {
        biased;
        _ = ct.cancelled() => {
            // Best-effort: kill by the run id if the Created event already
            // arrived (a sent oneshot value survives the sender drop). If it
            // hadn't, dropping the run future closes the run stream and the
            // master's disconnect_run auto-kill covers it.
            if let Ok(id) = created_rx.try_recv() {
                let host_owned = host.to_string();
                tokio::spawn(async move {
                    if let Ok(client) = RodeoClient::connect(&host_owned, port) {
                        let _ = client.kill(&id).await;
                    }
                });
            }
            let mut result = CallToolResult::error(vec![Content::text("cancelled by client")]);
            result.structured_content = Some(serde_json::json!({
                "stdout": "",
                "return_value": serde_json::Value::Null,
                "exit_code": 130,
                "error": "cancelled by client",
            }));
            result
        }
        output = run_fut => output.into_call_tool_result(),
    }
}

async fn handle_run_code(
    host: &str,
    port: u16,
    args: &serde_json::Value,
    on_created: Option<tokio::sync::oneshot::Sender<String>>,
) -> RunCodeOutput {
    let fail = |msg: String| RunCodeOutput {
        stdout: String::new(),
        return_value: None,
        exit_code: 1,
        error: Some(msg),
    };

    let code = args["code"].as_str().unwrap_or("").to_string();
    let dom_id = args["dom_id"].as_str().map(String::from);
    let studio_id = args["studio_id"].as_str().map(String::from);
    let script_args: Vec<String> = args["args"]
        .as_array()
        .map(|a| a.iter().filter_map(|v| v.as_str().map(String::from)).collect())
        .unwrap_or_default();
    let cache_requires = args["cache_requires"].as_bool().unwrap_or(false);
    let sourcemap = args["sourcemap"].as_str().map(String::from);
    let instance_path = args["instance_path"].as_str().map(String::from);
    let profile_dir = args["profile_dir"].as_str().map(std::path::PathBuf::from);
    let profile = args["profile"].as_bool().unwrap_or(false) || profile_dir.is_some();

    // Build + validate the routing spec (fast error to the agent).
    let route = match crate::shared::target::RouteSpec::from_strings(
        args["mode"].as_str(),
        args["dom"].as_str(),
        args["context"].as_str(),
    ).and_then(|r| { r.resolve()?; Ok(r) }) {
        Ok(r) => r,
        Err(e) => return fail(e.to_string()),
    };

    let output_file = args["output"]
        .as_str()
        .map(String::from)
        .unwrap_or_else(|| {
            std::env::temp_dir()
                .join(format!("rodeo-mcp-out-{}.txt", uuid::Uuid::new_v4()))
                .to_string_lossy()
                .to_string()
        });
    // The MCP handler used to mint its own UUID temp file to round-trip the
    // return value via disk. Now the return value rides on `ExecutionDone`
    // (read straight from `result.return_value`), so we only thread
    // `return_file` to the RunRequest when the caller explicitly asked for it.
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
        route,
        dom_id,
        session: studio_id,
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
        return_file: custom_return.clone(),
        show_return: false,
        output_file: Some(output_file.clone()),
        verbose: false,
        instance_path,
        script_path: sourcemap,
        profile,
        profile_dir,
        on_created,
    };

    let result = match cli_run::run_piped(host, port, request).await {
        Ok(r) => r,
        Err(e) => return fail(e.to_string()),
    };

    let mut stdout = String::new();
    let out_path = &output_file;
    if let Ok(out) = std::fs::read_to_string(out_path) {
        if !out.is_empty() {
            stdout.push_str(&out);
        }
        if args["output"].is_null() {
            let _ = std::fs::remove_file(out_path);
        }
    }

    // Return value flows over the wire — no disk read or temp file
    // management here. If the caller explicitly passed `return_file`, the
    // plugin wrote the value to that path instead (JSON, or Luau source for
    // .luau paths) and return_value is absent.
    let return_value = result.return_value.clone();

    let error = if result.exit_code != 0 {
        Some(if stdout.is_empty() {
            format!("Execution failed (exit code {})", result.exit_code)
        } else {
            stdout.clone()
        })
    } else {
        None
    };

    RunCodeOutput {
        stdout,
        return_value,
        exit_code: result.exit_code,
        error,
    }
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
        Ok(resp) => serde_json::to_value(resp.into_owned())
            .unwrap_or(serde_json::json!({"error": "serialize error"})),
        Err(e) => serde_json::json!({"error": e.to_string()}),
    }
}

async fn handle_get_slice(host: &str, port: u16, key: &str) -> serde_json::Value {
    let state = handle_get_state(host, port).await;
    state.get(key).cloned().unwrap_or(serde_json::json!([]))
}

async fn handle_kill_process(host: &str, port: u16, id: &str) -> Result<String, String> {
    RodeoClient::connect(host, port)
        .map_err(|e| e.to_string())?
        .kill(id)
        .await
        .map_err(|e| e.to_string())?;
    Ok(format!("Killed {id}"))
}

async fn handle_save_place(host: &str, port: u16, out: Option<String>) -> Result<String, String> {
    let result = RodeoClient::connect(host, port)
        .map_err(|e| e.to_string())?
        .save_default()
        .await
        .map_err(|e| e.to_string())?;
    let mut msg = "Place saved".to_string();
    if let Some(out_path) = out {
        if let Some(src_path) = result.path {
            std::fs::copy(&src_path, &out_path).map_err(|e| format!("Failed to copy: {e}"))?;
            msg = format!("Place saved and copied to {out_path}");
        }
    }
    Ok(msg)
}

async fn handle_launch_studio(host: &str, port: u16, args: LaunchStudioArgs) -> Result<String, String> {
    // Mirror the CLI's `--place` parsing: empty = new place, numeric = place ID,
    // anything else = file path.
    let place = args.place.unwrap_or_default();
    let target = if place.is_empty() {
        crate::studio_backend::PlaceTarget::Empty
    } else if let Ok(place_id) = place.parse::<u64>() {
        crate::studio_backend::PlaceTarget::PlaceId { place_id, universe_id: args.universe_id }
    } else {
        crate::studio_backend::PlaceTarget::File(place)
    };

    // The serve holds the Studio handle, so it stays available for follow-up
    // run_code requests regardless of `detached`; `detached` only decides
    // whether it also survives the server itself stopping.
    let req = super::run::build_launch_request(
        &target,
        !args.focus,
        None,
        crate::cli::FflagArgs::default(),
        args.detached,
        args.show_widgets.clone(),
        args.profile,
        host,
        port,
    )
    .await
    .map_err(|e| e.to_string())?;

    let (_backend, session_guid) = RodeoClient::connect(host, port)
        .map_err(|e| e.to_string())?
        .launch_studio_raw(req)
        .await
        .map_err(|e| e.to_string())?;

    Ok(format!("Studio launched (session {session_guid})"))
}

/// Convert MCP tool arguments (a JSON object) into argparse-style argv:
///   `{ "cframe": "...", "fov": 90, "verbose": true }`
///     → `["--cframe", "...", "--fov", "90", "--verbose"]`
/// Booleans become bare flags (false → omitted); null/missing values are dropped;
/// other scalars are stringified.
fn json_args_to_argv(args: &serde_json::Value) -> Vec<String> {
    let Some(obj) = args.as_object() else {
        return vec![];
    };
    let mut argv = Vec::with_capacity(obj.len() * 2);
    for (key, val) in obj {
        if val.is_null() {
            continue;
        }
        if let Some(b) = val.as_bool() {
            if b {
                argv.push(format!("--{key}"));
            }
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

async fn handle_luau_tool(
    host: &str,
    port: u16,
    script: String,
    route: crate::shared::target::RouteSpec,
    args: serde_json::Value,
) -> Result<String, String> {
    let return_file = std::env::temp_dir()
        .join(format!("rodeo-mcp-{}.json", uuid::Uuid::new_v4()))
        .to_string_lossy()
        .to_string();
    let output_file = std::env::temp_dir()
        .join(format!("rodeo-mcp-out-{}.txt", uuid::Uuid::new_v4()))
        .to_string_lossy()
        .to_string();

    let request = RunRequest {
        script,
        route,
        dom_id: None,
        session: None,
        log_filter: proto::LogFilter {
            enable_warn: true,
            enable_error: true,
            enable_info: true,
            enable_output: true,
            enable_logs: true,
            ..Default::default()
        },
        cache_requires: false,
        script_args: json_args_to_argv(&args),
        return_file: Some(return_file.clone()),
        show_return: false,
        output_file: Some(output_file.clone()),
        verbose: false,
        instance_path: None,
        script_path: None,
        profile: false,
        profile_dir: None,
        on_created: None,
    };

    let result = cli_run::run_piped(host, port, request)
        .await
        .map_err(|e| e.to_string())?;

    let mut output = String::new();
    if let Ok(out) = std::fs::read_to_string(&output_file) {
        if !out.is_empty() {
            output.push_str(&out);
        }
        let _ = std::fs::remove_file(&output_file);
    }
    if let Ok(ret) = std::fs::read_to_string(&return_file) {
        if !ret.is_empty() {
            if !output.is_empty() {
                output.push('\n');
            }
            output.push_str("[return] ");
            output.push_str(&ret);
        }
        let _ = std::fs::remove_file(&return_file);
    }

    if result.exit_code != 0 {
        if output.is_empty() {
            output = format!("Failed (exit code {})", result.exit_code)
        }
        return Err(output);
    }
    if output.is_empty() {
        output = "OK".to_string();
    }
    Ok(output)
}
