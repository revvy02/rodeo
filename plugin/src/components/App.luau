local React = require(script.Parent.Parent.Parent.packages.react)

local AppProvider = require(script.Parent.AppProvider)
local Container = require(script.Parent.Container)
local Label = require(script.Parent.Label)
local RodeoLabel = require(script.Parent.RodeoLabel)
local StatusIndicator = require(script.Parent.StatusIndicator)
local HostInput = require(script.Parent.HostInput)
local TextInput = require(script.Parent.TextInput)
local Checkbox = require(script.Parent.Checkbox)
local Button = require(script.Parent.Button)

local e = React.createElement

export type Settings = {
	port: number,
	autoConnect: boolean,
}

export type UICallbacks = {
	onConnect: (port: number) -> (),
	onDisconnect: () -> (),
	onSettingsChanged: (settings: Settings) -> (),
}

export type Props = {
	plugin: Plugin,
	initialSettings: Settings,
	callbacks: UICallbacks,
	connectionStatusRef: any,
}

local function App(props: Props)
	return e(AppProvider, {
		plugin = props.plugin,
		initialSettings = props.initialSettings,
		callbacks = props.callbacks,
		connectionStatusRef = props.connectionStatusRef,
	}, e(Container, {}, {
		-- Status indicator
		Status = e(StatusIndicator),

		-- Port row (combined host and port in single box)
		PortRow = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 30),
			LayoutOrder = 2,
		}, {
			Container = e("Frame", {
				BackgroundColor3 = Color3.fromRGB(20, 12, 14),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(0, 4),
				}),
				Stroke = e("UIStroke", {
					Color = Color3.fromRGB(200, 90, 100),
					Thickness = 1,
				}),
				HostInput = e(HostInput),
				PortInput = e(TextInput),
			}),
		}),

		-- Auto Connect row
		AutoConnectRow = e("Frame", {
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
			}),
			Checkbox = e(Checkbox),
		}),

		-- Button container
		ButtonContainer = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0.25),
			LayoutOrder = 4,
		}, {
			Button = e(Button),
		}),

		-- Rodeo label
		RodeoLabel = e(RodeoLabel),
	}))
end

return App
