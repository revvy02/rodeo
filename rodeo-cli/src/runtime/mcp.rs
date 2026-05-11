use rbx_control::studio::mcp_client::StudioMcpClient;
use serde_json::Value;
use std::sync::Arc;
use tokio::sync::Mutex;

/// Handle an `mcp.call` RPC request.
///
/// The mcp_studio_id is already resolved by the reconciliation loop in studio_state.
/// This just sets the active studio and forwards the tool call.
pub async fn handle_mcp_call(
    studio_mcp: Arc<Mutex<Option<StudioMcpClient>>>,
    mcp_studio_id: &str,
    tool: &str,
    arguments: &Value,
) -> Result<String, String> {
    let mcp_short = &mcp_studio_id[..8.min(mcp_studio_id.len())];
    let wait_start = std::time::Instant::now();
    tracing::info!(mcp_studio = mcp_short, tool, "mcp.call wait_lock");
    let mut mcp_guard = studio_mcp.lock().await;
    tracing::info!(mcp_studio = mcp_short, tool, wait_ms = wait_start.elapsed().as_millis() as u64, "mcp.call locked");
    let mcp = match mcp_guard.as_mut() {
        Some(mcp) => mcp,
        None => {
            return Err(
                "StudioMCP not connected yet. Enable MCP Server in Studio AI Assistant settings."
                    .into(),
            );
        }
    };

    let set_start = std::time::Instant::now();
    let set_res = mcp.set_active_studio(mcp_studio_id).await;
    tracing::info!(
        mcp_studio = mcp_short,
        tool,
        ok = set_res.is_ok(),
        elapsed_ms = set_start.elapsed().as_millis() as u64,
        "mcp.set_active_studio done"
    );
    set_res.map_err(|e| format!("set_active_studio failed: {e}"))?;

    let call_start = std::time::Instant::now();
    let call_res = mcp.call_tool(tool, arguments).await;
    tracing::info!(
        mcp_studio = mcp_short,
        tool,
        ok = call_res.is_ok(),
        elapsed_ms = call_start.elapsed().as_millis() as u64,
        "mcp.call_tool done"
    );
    call_res
}
