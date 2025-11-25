local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

export type Props = {}

local function HostInput()
	local context = useAppContext()

	local function handleFocusLost(rbx: TextBox)
		context.setHost(rbx.Text)
	end

	return e("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.new(0.6, -4, 1, 0),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Text = context.settings.host,
		TextColor3 = context.COLORS.text,
		PlaceholderText = "localhost",
		PlaceholderColor3 = context.COLORS.textDim,
		TextSize = 18,
		TextScaled = true,
		Font = Enum.Font.Arcade,
		TextXAlignment = Enum.TextXAlignment.Left,
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

return HostInput
