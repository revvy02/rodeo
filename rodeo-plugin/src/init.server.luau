--[[
	Rodeo Plugin Entry Point

	Bootstraps the React UI. All connection and execution logic
	lives in React hooks (useWebSocket, useExecution).
	AppProvider is the single source of truth for all state.

	The app is always mounted (for WebSocket to work in "once" mode).
	The settings panel (widget/toolbar) is only created when SETTINGS_PANEL_ENABLED.
]]

local App = require(script.app.widget)
local React = require("@pkg/react")
local ReactRoblox = require("@pkg/react_roblox")
local assets = require(script.library.assets)
local flags = require(script.library.flags)

local e = React.createElement

local WIDGET_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, -- Initially disabled
	false, -- Override previous enabled state
	350, -- Default width
	400, -- Default height
	300, -- Minimum width
	350 -- Minimum height
)

-- Create widget
local widgetId = "Rodeo-" .. tostring(flags.SETTINGS.port)
local widget = plugin:CreateDockWidgetPluginGui(widgetId, WIDGET_INFO)
widget.Title = "Rodeo"

-- Only create toolbar button when settings panel is enabled
if flags.SETTINGS_PANEL_ENABLED then
	local toolbar = plugin:CreateToolbar("rodeo")
	local toggleButton = toolbar:CreateButton("Rodeo", "Toggle Rodeo Plugin UI", assets.rodeo)

	toggleButton.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)

	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		toggleButton:SetActive(widget.Enabled)
	end)
end

-- Match guard: if MATCH is set, only mount if game properties match.
-- Launched plugins have MATCH baked in (e.g. { placeId = 12345, gameId = 678 }).
-- The manual plugin has MATCH = nil and always mounts.
if flags.MATCH then
	if flags.MATCH.placeId ~= game.PlaceId then
		return
	end
	if flags.MATCH.gameId and flags.MATCH.gameId ~= 0 and flags.MATCH.gameId ~= game.GameId then
		return
	end
end

-- Session-attribute guard: only fires for local-file launches where rodeo could
-- stamp the attribute. Published-place launches (Studio downloads from servers)
-- set this false and rely on MATCH (placeId/gameId) for isolation.
if flags.CHECK_WORKSPACE_SESSION_GUID_ATTR_MATCHES then
	local attr = game:GetService("Workspace"):GetAttribute("__RODEO_SESSION_GUID__")
	if attr ~= flags.SESSION_GUID then
		return
	end
end

-- Create React root and render (always, for WebSocket to work)
local root = ReactRoblox.createRoot(widget)

-- Priority: persisted plugin setting > flags default
local persistedAutoConnect = plugin:GetSetting("autoConnect")
local resolvedAutoConnect = if persistedAutoConnect ~= nil then persistedAutoConnect else flags.SETTINGS.autoConnect

local resolvedSettings = {
	host = flags.SETTINGS.host,
	port = flags.SETTINGS.port,
	autoConnect = resolvedAutoConnect,
}

root:render(e(App, {
	plugin = plugin,
	initialSettings = resolvedSettings,
}))

-- Cleanup on plugin unload
plugin.Unloading:Connect(function()
	root:unmount()
	widget:Destroy()
end)
