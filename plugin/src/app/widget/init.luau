local React = require("@pkg/react")

local AppContext = require(script.Parent.context.AppContext)
local Button = require(script.Button)
local Checkbox = require(script.Checkbox)
local Container = require(script.Container)
local Label = require(script.Label)
local RodeoLabel = require(script.RodeoLabel)
local Row = require(script.Row)
local StatusIndicator = require(script.StatusIndicator)
local TextInput = require(script.TextInput)
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
	local isConnected = context.connected

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
				text = "> Auto Connect",
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
				text = "> Verbose",
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

		-- Button (only when settings panel enabled)
		-- When connected: red text/stroke (disconnect action)
		-- When disconnected: green text/stroke (connect action)
		Button = showSettings and e(Button, {
			text = if isConnected then "DISCONNECT" else "CONNECT",
			color = if isConnected then COLORS.error else COLORS.success,
			strokeColor = if isConnected then COLORS.error else COLORS.success,
			size = UDim2.fromOffset(140, 50),
			layoutOrder = 5,
			onClick = if isConnected then context.disconnect else context.connect,
		}) or nil,

		-- Rodeo label (always shown)
		RodeoLabel = e(RodeoLabel),
	})
end

local function App(props: Props)
	return e("Frame", {
		BackgroundColor3 = COLORS.background,
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, {
		Content = e(AppProvider, {
			plugin = props.plugin,
			initialSettings = props.initialSettings,
		}, e(AppContent)),
	})
end

return App
