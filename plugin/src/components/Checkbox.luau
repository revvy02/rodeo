local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

export type Props = {}

local function Checkbox()
	local context = useAppContext()

	local function handleActivated()
		context.setAutoConnect(not context.settings.autoConnect)
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(24, 24),
		LayoutOrder = 2,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 4),
		}),
		Stroke = e("UIStroke", {
			Color = context.COLORS.stroke,
			Thickness = 1,
		}),
		Button = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 0),
			Text = "",
			[React.Event.Activated] = handleActivated,
		}, {
			Checkmark = e("TextLabel", {
				Text = if context.settings.autoConnect then "✓" else "",
				TextColor3 = context.COLORS.accent,
				TextSize = 18,
				Font = Enum.Font.Arcade,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return Checkbox
