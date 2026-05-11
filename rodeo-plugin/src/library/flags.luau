-- Flags patched at build time by CLI
-- DO NOT modify the default values - they are used as markers for string replacement
-- For launched plugins, the CLI patches the Source of this ModuleScript in the .rbxm
-- with launch-specific config (port, host, match criteria) before writing to plugins dir.
return {
	VERSION = RODEO_VERSION,
	VERBOSE = false,
	SETTINGS_PANEL_ENABLED = true,
	SETTINGS = {
		host = "localhost",
		-- Studio backend port (= rodeo-cli's SERVE_PORT + 1). The
		-- manually-installed plugin auto-connects to the studio backend's
		-- WebSocket, not to master directly. Keep in sync with
		-- rodeo-cli/src/util/config.rs::SERVE_PORT.
		port = 44873,
		autoConnect = true,
	},
	MATCH = nil, -- nil = accept any (manual install), or { placeId = N, gameId = N }
	-- Rodeo session identity. Set for rodeo-launched plugins; nil for manual install.
	-- Sent on the first WS message so master can stamp the VM's session synchronously.
	SESSION_GUID = nil,
	-- When true, the plugin additionally requires `Workspace:GetAttribute("__RODEO_SESSION_GUID__")`
	-- to match SESSION_GUID before activating. Only set true for local-file launches where
	-- rodeo was able to stamp the attribute; false for published-place launches where Studio
	-- downloads the place from Roblox servers (MATCH gates those).
	CHECK_WORKSPACE_SESSION_GUID_ATTR_MATCHES = false,
}
