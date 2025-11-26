local React = require(script.Parent.Parent.Parent:WaitForChild('packages'):WaitForChild('react'))

local AppContext = require(script.Parent.context.AppContext)
local Container = require(script.Container)
local Label = require(script.Label)
local RodeoLabel = require(script.RodeoLabel)
local Row = require(script.Row)
local StatusIndicator = require(script.StatusIndicator)
local TextInput = require(script.TextInput)
local Checkbox = require(script.Checkbox)
local Button = require(script.Button)
local constants = require(script.Parent.Parent.constants)

local AppProvider = AppContext.AppProvider
local useAppContext = AppContext.useAppContext

local COLORS = constants.COLORS

local e = React.createElement

export type Props = {
	plugin: Plugin,
	initialSettings: {
		host: string?,
		port: number,
		autoConnect: boolean,
	},
}

-- Inner component that can use context
local function AppContent()
	local context = useAppContext()
	local showSettings = context.settingsPanelEnabled
	local isConnected = context.connectionStatus.connected

	return e(Container, {}, {
		-- Status indicator (always shown)
		Status = e(StatusIndicator),

		-- Port row (only when settings panel enabled)
		PortRow = showSettings and e(Row, {
			height = 30,
			layoutOrder = 2,
		}, {
			Container = e("Frame", {
				BackgroundColor3 = COLORS.inputBackground,
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				Layout = e("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 8),
				}),
				Padding = e("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 8),
				}),
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				Stroke = e("UIStroke", {
					Color = COLORS.stroke,
					Thickness = 1,
				}),
				HostInput = e(TextInput, {
					value = context.settings.host,
					placeholder = context.settings.defaultHost,
					textColor = COLORS.text,
					placeholderColor = COLORS.textDim,
					textXAlignment = Enum.TextXAlignment.Left,
					onValueChange = context.setHost,
				}),
				PortInput = e(TextInput, {
					value = context.settings.port,
					placeholder = context.settings.defaultPort,
					textColor = COLORS.text,
					placeholderColor = COLORS.textDim,
					textXAlignment = Enum.TextXAlignment.Right,
					onValueChange = context.setPort,
				}),
			}),
		}) or nil,

		-- Auto Connect row (only when settings panel enabled)
		AutoConnectRow = showSettings and e(Row, {
			height = 30,
			layoutOrder = 3,
		}, {
			Label = e(Label, {
				text = "Auto Connect",
				textColor = COLORS.accent,
			}),
			Checkbox = e(Checkbox, {
				checked = context.settings.autoConnect,
				strokeColor = COLORS.stroke,
				onToggle = function()
					context.setAutoConnect(not context.settings.autoConnect)
				end,
			}),
		}) or nil,

		-- Verbose row (only when settings panel enabled)
		VerboseRow = showSettings and e(Row, {
			height = 30,
			layoutOrder = 4,
		}, {
			Label = e(Label, {
				text = "Verbose",
				textColor = COLORS.accent,
			}),
			Checkbox = e(Checkbox, {
				checked = context.settings.verbose,
				strokeColor = COLORS.stroke,
				onToggle = function()
					context.setVerbose(not context.settings.verbose)
				end,
			}),
		}) or nil,

		-- Button container (only when settings panel enabled)
		ButtonContainer = showSettings and e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = 5,
		}, {
			Button = e(Button, {
				text = if isConnected then "DISCONNECT" else "CONNECT",
				color = if isConnected then COLORS.buttonDisconnect else COLORS.buttonConnect,
				backgroundColor = COLORS.buttonBackground,
				hoverBackgroundColor = COLORS.buttonHover,
				onClick = if isConnected then context.disconnect else context.connect,
			}),
		}) or nil,

		-- Rodeo label (always shown)
		RodeoLabel = e(RodeoLabel),
	})
end

local function App(props: Props)
	return e(AppProvider, {
		plugin = props.plugin,
		initialSettings = props.initialSettings,
	}, e(AppContent))
end

return App
