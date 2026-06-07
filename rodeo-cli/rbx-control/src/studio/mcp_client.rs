use serde_json::Value;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tracing::warn;

/// Client for the StudioMCP subprocess (stdio JSON-RPC).
///
/// Spawns `StudioMCP` from the Roblox Studio install and speaks MCP
/// over stdin/stdout. The `client_name` supplied to [`Self::new`] is sent
/// in the `initialize` handshake's `clientInfo.name` field — Studio shows
/// this in its AI-assistant UI as the connected client.
pub struct StudioMcpClient {
    stdin: tokio::process::ChildStdin,
    stdout: BufReader<tokio::process::ChildStdout>,
    #[allow(dead_code)]
    child: tokio::process::Child,
    next_id: u32,
}

impl StudioMcpClient {
    pub async fn new(client_name: &str) -> Result<Self, String> {
        let mcp_path = crate::paths::studio_mcp_path()
            .ok_or_else(|| "could not locate StudioMCP binary".to_string())?;
        let mut child = tokio::process::Command::new(&mcp_path)
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::inherit())
            .kill_on_drop(true)
            .spawn()
            .map_err(|e| format!("failed to spawn StudioMCP: {e}"))?;

        let stdin = child.stdin.take().ok_or("no stdin")?;
        let stdout = BufReader::new(child.stdout.take().ok_or("no stdout")?);

        let mut client = Self {
            stdin,
            stdout,
            child,
            next_id: 1,
        };

        // Init handshake
        let init = format!(
            r#"{{"jsonrpc":"2.0","id":0,"method":"initialize","params":{{"protocolVersion":"2025-03-26","capabilities":{{}},"clientInfo":{{"name":{},"version":"0.1"}}}}}}"#,
            serde_json::Value::String(client_name.to_string()),
        );
        client.send_raw(&init).await?;
        client.recv_line().await?;
        client
            .send_raw(r#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#)
            .await?;

        Ok(client)
    }

    async fn send_raw(&mut self, line: &str) -> Result<(), String> {
        self.stdin
            .write_all(format!("{line}\n").as_bytes())
            .await
            .map_err(|e| format!("write: {e}"))?;
        self.stdin
            .flush()
            .await
            .map_err(|e| format!("flush: {e}"))
    }

    async fn recv_line(&mut self) -> Result<String, String> {
        let mut line = String::new();
        // Timeout prevents MCP going unresponsive from blocking the mcp mutex indefinitely
        // (which would wedge every other caller waiting on StudioMCP).
        let read = tokio::time::timeout(
            std::time::Duration::from_secs(10),
            self.stdout.read_line(&mut line),
        )
        .await
        .map_err(|_| "StudioMCP read timed out after 10s".to_string())?;
        read.map_err(|e| format!("read: {e}"))?;
        Ok(line)
    }

    /// Send a JSON-RPC request and wait for the matching response (skipping notifications).
    async fn rpc(&mut self, method: &str, params: Value) -> Result<Value, String> {
        let id = self.next_id;
        self.next_id += 1;

        let req = serde_json::json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params
        });
        self.send_raw(&serde_json::to_string(&req).unwrap())
            .await?;

        loop {
            let line = self.recv_line().await?;
            if line.is_empty() {
                warn!("StudioMCP closed (empty line)");
                return Err("StudioMCP closed".into());
            }
            let resp: Value =
                serde_json::from_str(&line).map_err(|e| format!("json parse: {e}"))?;

            let resp_id = resp
                .get("id")
                .and_then(|v| v.as_u64().or_else(|| v.as_str().and_then(|s| s.parse().ok())));

            if resp_id == Some(id as u64) {
                if let Some(error) = resp.get("error") {
                    let msg = error["message"].as_str().unwrap_or("unknown");
                    warn!(mcp_id = id, %method, error = msg, "mcp error");
                    return Err(format!("StudioMCP error: {msg}"));
                }
                return Ok(resp["result"].clone());
            }
            // Notification or mismatched id — skip
        }
    }

    /// Call a StudioMCP tool and return the text result.
    pub async fn call_tool(&mut self, tool: &str, arguments: &Value) -> Result<String, String> {
        let result = self.call_tool_raw(tool, arguments).await?;

        let text = result["content"]
            .as_array()
            .and_then(|a| a.first())
            .and_then(|c| c["text"].as_str())
            .unwrap_or("")
            .to_string();

        if result["isError"].as_bool() == Some(true) {
            warn!(tool, error = text.as_str(), "mcp tool error");
            return Err(text);
        }
        Ok(text)
    }

    /// Call a StudioMCP tool and return the raw result Value (for passthrough).
    pub async fn call_tool_raw(&mut self, tool: &str, arguments: &Value) -> Result<Value, String> {
        self.rpc("tools/call", serde_json::json!({ "name": tool, "arguments": arguments }))
            .await
    }

    /// Get the tool list from StudioMCP.
    pub async fn list_tools(&mut self) -> Result<Vec<Value>, String> {
        let result = self.rpc("tools/list", serde_json::json!({})).await?;
        Ok(result["tools"].as_array().cloned().unwrap_or_default())
    }

    /// List all connected Studio DataModels (each is a "studio" with a UUID).
    pub async fn list_studios(&mut self) -> Result<Vec<StudioEntry>, String> {
        let text = self.call_tool("list_roblox_studios", &serde_json::json!({})).await?;
        // StudioMCP may return either a bare array or {"studios": [...]}
        let entries: Vec<StudioEntry> = if text.starts_with('{') {
            let wrapper: serde_json::Value =
                serde_json::from_str(&text).map_err(|e| format!("parse list_roblox_studios: {e}"))?;
            serde_json::from_value(wrapper["studios"].clone())
                .map_err(|e| format!("parse list_roblox_studios.studios: {e}"))?
        } else {
            serde_json::from_str(&text).map_err(|e| format!("parse list_roblox_studios: {e}"))?
        };
        Ok(entries)
    }

    /// Set the active Studio DataModel for subsequent tool calls.
    /// `mcp_studio_id` is StudioMCP's own id (not our canonical studio_id).
    pub async fn set_active_studio(&mut self, mcp_studio_id: &str) -> Result<(), String> {
        self.call_tool(
            "set_active_studio",
            &serde_json::json!({ "studio_id": mcp_studio_id }),
        )
        .await?;
        Ok(())
    }

    /// Execute Luau code via StudioMCP's execute_luau tool in a specific
    /// DataModel. `datamodel_type` must be one of "Edit", "Server", "Client"
    /// (StudioMCP requires it; the target type must be available in the
    /// Studio's current mode or the call errors).
    pub async fn execute_luau(
        &mut self,
        code: &str,
        datamodel_type: &str,
    ) -> Result<String, String> {
        self.call_tool(
            "execute_luau",
            &serde_json::json!({ "code": code, "datamodel_type": datamodel_type }),
        )
        .await
    }

}

#[derive(Debug, Clone, serde::Deserialize)]
#[allow(dead_code)]
pub struct StudioEntry {
    /// StudioMCP's internal id for this Studio. Distinct from our canonical
    /// master-assigned `studio_id` (which master tracks in studio_instances
    /// and stamps on each VM as canonical_studio_id).
    #[serde(rename = "id")]
    pub mcp_studio_id: String,
    pub name: Option<String>,
    pub active: bool,
}
