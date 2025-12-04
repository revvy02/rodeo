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
local widget = plugin:CreateDockWidgetPluginGui("Rodeo", WIDGET_INFO)
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

-- Create React root and render (always, for WebSocket to work)
local root = ReactRoblox.createRoot(widget)

root:render(e(App, {
	plugin = plugin,
	initialSettings = {
		host = flags.SETTINGS.host,
		port = flags.SETTINGS.port,
		autoConnect = flags.SETTINGS.autoConnect,
	},
}))

-- Cleanup on plugin unload
plugin.Unloading:Connect(function()
	root:unmount()
	widget:Destroy()
end)
