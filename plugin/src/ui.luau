-- React-based UI for rodeo plugin
local App = require(script.Parent.components.App)
local React = require(script.Parent.Parent.packages.react)
local ReactRoblox = require(script.Parent.Parent.packages["react_roblox"])

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

export type UICallbacks = {
	onConnect: (port: number) -> (),
	onDisconnect: () -> (),
	onSettingsChanged: (settings: { port: number, autoConnect: boolean }) -> (),
}

export type UIHandle = {
	setConnectionStatus: (connected: boolean, message: string?) -> (),
	destroy: () -> (),
}

return function(pluginInstance: Plugin, initialSettings: { port: number, autoConnect: boolean }, callbacks: UICallbacks): UIHandle
	local widget = pluginInstance:CreateDockWidgetPluginGui("RodeoSettings", WIDGET_INFO)
	widget.Title = "Rodeo"

	-- Create toolbar button to toggle widget
	local toolbar = pluginInstance:CreateToolbar("rodeo")
	local toggleButton = toolbar:CreateButton("Settings", "Toggle Rodeo settings panel", "rbxasset://textures/ui/Settings/MenuBarIcons/GameSettingsTab.png")

	toggleButton.Click:Connect(function()
		widget.Enabled = not widget.Enabled
	end)

	widget:GetPropertyChangedSignal("Enabled"):Connect(function()
		toggleButton:SetActive(widget.Enabled)
	end)

	-- Create React root
	local root = ReactRoblox.createRoot(widget)

	-- Create ref for imperative updates
	local connectionStatusRef = React.createRef()

	-- Render React tree
	root:render(e(App, {
		plugin = pluginInstance,
		initialSettings = initialSettings,
		callbacks = callbacks,
		connectionStatusRef = connectionStatusRef,
	}))

	-- Return handle for imperative updates
	local handle: UIHandle = {
		setConnectionStatus = function(connected: boolean, message: string?)
			-- Call the exposed function via ref
			if connectionStatusRef.current then
				connectionStatusRef.current.setConnectionStatus(connected, message)
			end
		end,
		destroy = function()
			root:unmount()
			widget:Destroy()
		end,
	}

	return handle
end
