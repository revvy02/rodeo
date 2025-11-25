-- Rojo-style settings panel UI for rodeo plugin
local WIDGET_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Right,
	false, -- Initially disabled
	false, -- Override previous enabled state
	300, -- Default width
	200, -- Default height
	200, -- Minimum width
	150 -- Minimum height
)

local COLORS = {
	background = Color3.fromRGB(46, 46, 46),
	backgroundLight = Color3.fromRGB(60, 60, 60),
	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(170, 170, 170),
	accent = Color3.fromRGB(0, 162, 255),
	accentHover = Color3.fromRGB(30, 180, 255),
	success = Color3.fromRGB(0, 200, 100),
	error = Color3.fromRGB(255, 80, 80),
	buttonRed = Color3.fromRGB(220, 60, 60),
	border = Color3.fromRGB(80, 80, 80),
	inputBackground = Color3.fromRGB(35, 35, 35),
}

local function createLabel(parent: Frame, text: string, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.4, 0, 0, 24)
	label.Position = position
	label.Text = text
	label.TextColor3 = COLORS.textDim
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createTextInput(parent: Frame, defaultValue: string, position: UDim2): TextBox
	local input = Instance.new("TextBox")
	input.BackgroundColor3 = COLORS.inputBackground
	input.BorderColor3 = COLORS.border
	input.BorderSizePixel = 1
	input.Size = UDim2.new(0.5, 0, 0, 24)
	input.Position = UDim2.new(1, 0, position.Y.Scale, position.Y.Offset)
	input.AnchorPoint = Vector2.new(1, 0)
	input.Text = defaultValue
	input.TextColor3 = COLORS.text
	input.PlaceholderColor3 = COLORS.textDim
	input.TextSize = 14
	input.Font = Enum.Font.GothamMedium
	input.ClearTextOnFocus = false
	input.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = input

	return input
end

local function createCheckbox(parent: Frame, checked: boolean, position: UDim2): TextButton
	local checkbox = Instance.new("TextButton")
	checkbox.BackgroundColor3 = if checked then COLORS.accent else COLORS.inputBackground
	checkbox.BorderColor3 = COLORS.border
	checkbox.BorderSizePixel = 1
	checkbox.Size = UDim2.new(0, 24, 0, 24)
	checkbox.Position = UDim2.new(1, 0, position.Y.Scale, position.Y.Offset)
	checkbox.AnchorPoint = Vector2.new(1, 0)
	checkbox.Text = if checked then "✓" else ""
	checkbox.TextColor3 = COLORS.text
	checkbox.TextSize = 16
	checkbox.Font = Enum.Font.GothamBold
	checkbox.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = checkbox

	return checkbox
end

local function createButton(parent: Frame, text: string, position: UDim2, size: UDim2, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Size = size
	button.Position = position
	button.Text = text
	button.TextColor3 = COLORS.text
	button.TextSize = 14
	button.Font = Enum.Font.GothamMedium
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	-- Hover effect
	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Color3.new(
			math.min(color.R + 0.1, 1),
			math.min(color.G + 0.1, 1),
			math.min(color.B + 0.1, 1)
		)
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = color
	end)

	return button
end

local function createStatusIndicator(parent: Frame, position: UDim2): Frame
	local container = Instance.new("Frame")
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(1, 0, 0, 24)
	container.Position = position
	container.Parent = parent

	local dot = Instance.new("Frame")
	dot.BackgroundColor3 = COLORS.error
	dot.BorderSizePixel = 0
	dot.Size = UDim2.new(0, 10, 0, 10)
	dot.Position = UDim2.new(0, 0, 0.5, -5)
	dot.Parent = container

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -16, 1, 0)
	label.Position = UDim2.new(0, 16, 0, 0)
	label.Text = "Disconnected"
	label.TextColor3 = COLORS.textDim
	label.TextSize = 14
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = container

	return container
end

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

	-- Main container
	local container = Instance.new("Frame")
	container.BackgroundColor3 = COLORS.background
	container.BorderSizePixel = 0
	container.Size = UDim2.new(1, 0, 1, 0)
	container.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = container

	-- Status section
	local statusIndicator = createStatusIndicator(container, UDim2.new(0, 0, 0, 0))
	local statusDot = statusIndicator:FindFirstChildWhichIsA("Frame")
	local statusLabel = statusIndicator:FindFirstChildWhichIsA("TextLabel")

	-- Port input
	createLabel(container, "Port", UDim2.new(0, 0, 0, 36))
	local portInput = createTextInput(container, tostring(initialSettings.port), UDim2.new(0.4, 0, 0, 36))

	-- Auto Connect checkbox
	createLabel(container, "Auto Connect", UDim2.new(0, 0, 0, 72))
	local autoConnectCheckbox = createCheckbox(container, initialSettings.autoConnect, UDim2.new(0.4, 0, 0, 72))
	local autoConnectEnabled = initialSettings.autoConnect

	autoConnectCheckbox.Activated:Connect(function()
		autoConnectEnabled = not autoConnectEnabled
		autoConnectCheckbox.Text = if autoConnectEnabled then "✓" else ""
		autoConnectCheckbox.BackgroundColor3 = if autoConnectEnabled then COLORS.accent else COLORS.inputBackground
		callbacks.onSettingsChanged({
			port = tonumber(portInput.Text) or initialSettings.port,
			autoConnect = autoConnectEnabled,
		})
	end)

	portInput.FocusLost:Connect(function()
		local port = tonumber(portInput.Text)
		if port and port > 0 and port < 65536 then
			callbacks.onSettingsChanged({
				port = port,
				autoConnect = autoConnectEnabled,
			})
		else
			portInput.Text = tostring(initialSettings.port)
		end
	end)

	-- Connect/Disconnect button
	local connectButton = createButton(
		container,
		"Connect",
		UDim2.new(0, 0, 0, 112),
		UDim2.new(1, 0, 0, 32),
		COLORS.buttonRed
	)

	local isConnected = false

	local function updateButtonState()
		if isConnected then
			connectButton.Text = "Disconnect"
		else
			connectButton.Text = "Connect"
		end
	end

	connectButton.Activated:Connect(function()
		if isConnected then
			callbacks.onDisconnect()
		else
			local port = tonumber(portInput.Text) or initialSettings.port
			callbacks.onConnect(port)
		end
	end)

	local handle: UIHandle = {
		setConnectionStatus = function(connected: boolean, message: string?)
			isConnected = connected
			updateButtonState()
			if connected then
				statusDot.BackgroundColor3 = COLORS.success
				statusLabel.Text = message or "Connected"
				statusLabel.TextColor3 = COLORS.success
			else
				statusDot.BackgroundColor3 = COLORS.error
				statusLabel.Text = message or "Disconnected"
				statusLabel.TextColor3 = COLORS.textDim
			end
		end,
		destroy = function()
			widget:Destroy()
		end,
	}

	return handle
end
