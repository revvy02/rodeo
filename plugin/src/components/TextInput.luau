local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

export type Props = {}

local function TextInput()
	local context = useAppContext()

	local function handleFocusLost(rbx: TextBox)
		context.setPort(rbx.Text)
	end

	return e("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0.4, -4, 1, 0),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Text = context.settings.port,
		TextColor3 = context.COLORS.text,
		PlaceholderColor3 = context.COLORS.textDim,
		TextSize = 18,
		TextScaled = true,
		Font = Enum.Font.Arcade,
		TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		[React.Event.FocusLost] = handleFocusLost,
	}, {
		TextSizeConstraint = e("UITextSizeConstraint", {
			MaxTextSize = 18,
			MinTextSize = 12,
		}),
		Gradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 150)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 90, 100)),
			}),
			Rotation = 90,
		}),
	})
end

return TextInput
