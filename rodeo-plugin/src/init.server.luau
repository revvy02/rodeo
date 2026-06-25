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
local constants = require(script.library.constants)

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
local widgetId = "Rodeo-" .. tostring(constants.DEFAULT_PORT)
local widget = plugin:CreateDockWidgetPluginGui(widgetId, WIDGET_INFO)
widget.Title = "Rodeo"

-- Toolbar toggle for the settings panel. The widget starts disabled, so a
-- rodeo-launched Studio just carries a dormant button until the user opens it.
local toolbar = plugin:CreateToolbar("rodeo")
local toggleButton = toolbar:CreateButton("Rodeo", "Toggle Rodeo Plugin UI", assets.rodeo)

toggleButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	toggleButton:SetActive(widget.Enabled)
end)

-- No activation gates: this is a single static plugin, so the only instance in
-- a given Studio is the right one. A rodeo launch routes this plugin via the
-- `rodeoPort`/`rodeoSession` workspace attributes its RunScript bootstrap sets;
-- a manual Studio just connects on the defaults.

-- Create React root and render (always, for WebSocket to work)
local root = ReactRoblox.createRoot(widget)

-- Priority: persisted plugin setting > constant default
local persistedAutoConnect = plugin:GetSetting("autoConnect")
local resolvedAutoConnect = if persistedAutoConnect ~= nil then persistedAutoConnect else constants.DEFAULT_AUTO_CONNECT

local resolvedSettings = {
	host = constants.DEFAULT_HOST,
	port = constants.DEFAULT_PORT,
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
