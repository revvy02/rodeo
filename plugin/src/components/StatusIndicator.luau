local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

local function StatusIndicator()
	local context = useAppContext()
	local connected = context.connectionStatus.connected
	local message = context.connectionStatus.message

	local dotColor = if connected then context.COLORS.success else context.COLORS.error
	local labelColor = if connected then context.COLORS.success else context.COLORS.textDim

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 24),
		LayoutOrder = 1,
	}, {
		Dot = e("Frame", {
			BackgroundColor3 = dotColor,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
			Position = UDim2.new(0, 0, 0.5, -5),
		}, {
			Corner = e("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
		}),
		Label = e("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.fromOffset(20, 0),
			Text = message,
			TextColor3 = labelColor,
			TextSize = 18,
			TextScaled = true,
			Font = Enum.Font.Arcade,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, {
			TextSizeConstraint = e("UITextSizeConstraint", {
				MaxTextSize = 18,
				MinTextSize = 12,
			}),
		}),
	})
end

return StatusIndicator
