--[[
	Rodeo Plugin Entry Point

	Bootstraps the React UI. All connection and execution logic lives in
	AppProvider, which auto-connects on load to this plugin's own studio
	backend — the port the installing backend baked into the plugin file
	(constants.PORT). One plugin file per running backend, so several rodeo
	plugins can be loaded in one Studio; AppProvider decides whether this one
	is active here (see its auto-connect effect).

	The app is always mounted (the widget is the mount point) so the WebSocket
	runs; the panel itself just shows connection status, active runs, and a
	verbose toggle. The toolbar button appears on the first connection, so a
	plugin with no backend shows nothing.
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

-- Create widget. Id and title carry this plugin's port and version: two
-- rodeo plugins can be loaded at once, and Studio keys dock state by id.
local widgetId = "Rodeo-" .. tostring(constants.PORT)
local widget = plugin:CreateDockWidgetPluginGui(widgetId, WIDGET_INFO)
widget.Title = `Rodeo v{constants.VERSION}`

-- Toolbar toggle for the panel, created on the first successful connection
-- so a plugin with no backend — its serve is gone, or this Studio belongs to
-- another backend — shows nothing. The widget itself starts disabled.
local toggleButton: PluginToolbarButton? = nil
local function ensureToolbar()
	if toggleButton then
		return
	end
	local toolbar = plugin:CreateToolbar(`Rodeo v{constants.VERSION}`)
	local button = toolbar:CreateButton("Rodeo", "Toggle Rodeo Plugin UI", assets.rodeo)
	button.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)
	button:SetActive(widget.Enabled)
	toggleButton = button
end

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if toggleButton then
		toggleButton:SetActive(widget.Enabled)
	end
end)

-- Create React root and render (always, for WebSocket to work)
local root = ReactRoblox.createRoot(widget)

root:render(e(App, {
	plugin = plugin,
	initialSettings = {
		port = constants.PORT,
	},
	onConnected = ensureToolbar,
}))

-- Cleanup on plugin unload
plugin.Unloading:Connect(function()
	root:unmount()
	widget:Destroy()
end)
