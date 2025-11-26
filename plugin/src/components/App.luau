local React = require(script.Parent.Parent.Parent.packages.react)

local AppProvider = require(script.Parent.AppProvider)
local Container = require(script.Parent.Container)
local Label = require(script.Parent.Label)
local RodeoLabel = require(script.Parent.RodeoLabel)
local StatusIndicator = require(script.Parent.StatusIndicator)
local TextInput = require(script.Parent.TextInput)
local Checkbox = require(script.Parent.Checkbox)
local Button = require(script.Parent.Button)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

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
		PortRow = showSettings and e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 2,
		}, {
			Container = e("Frame", {
				BackgroundColor3 = context.COLORS.inputBackground,
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
					Color = context.COLORS.stroke,
					Thickness = 1,
				}),
				HostInput = e(TextInput, {
					value = context.settings.host,
					placeholder = "localhost",
					textColor = context.COLORS.text,
					placeholderColor = context.COLORS.textDim,
					textXAlignment = Enum.TextXAlignment.Left,
					onValueChange = context.setHost,
				}),
				PortInput = e(TextInput, {
					value = context.settings.port,
					placeholder = "44872",
					textColor = context.COLORS.text,
					placeholderColor = context.COLORS.textDim,
					textXAlignment = Enum.TextXAlignment.Right,
					onValueChange = context.setPort,
				}),
			}),
		}) or nil,

		-- Auto Connect row (only when settings panel enabled)
		AutoConnectRow = showSettings and e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 3,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Label = e(Label, {
				text = "Auto Connect",
				textColor = context.COLORS.accent,
			}),
			Checkbox = e(Checkbox, {
				checked = context.settings.autoConnect,
				strokeColor = context.COLORS.stroke,
				accentColor = context.COLORS.accent,
				onToggle = function()
					context.setAutoConnect(not context.settings.autoConnect)
				end,
			}),
		}) or nil,

		-- Button container (only when settings panel enabled)
		ButtonContainer = showSettings and e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = 4,
		}, {
			Button = e(Button, {
				text = if isConnected then "DISCONNECT" else "CONNECT",
				color = if isConnected then context.COLORS.buttonDisconnect else context.COLORS.buttonConnect,
				backgroundColor = context.COLORS.buttonBackground,
				hoverBackgroundColor = context.COLORS.buttonHover,
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
