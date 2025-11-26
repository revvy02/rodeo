local React = require(script.Parent.Parent.Parent.Parent:WaitForChild('packages'):WaitForChild('react'))

local e = React.createElement

export type Props = {
	value: string,
	placeholder: string?,
	textColor: Color3,
	placeholderColor: Color3?,
	textXAlignment: Enum.TextXAlignment?,
	onValueChange: (value: string) -> (),
}

local function TextInput(props: Props)
	local function handleFocusLost(rbx: TextBox)
		props.onValueChange(rbx.Text)
	end

	return e("TextBox", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = props.value,
		TextColor3 = props.textColor,
		PlaceholderText = props.placeholder,
		PlaceholderColor3 = props.placeholderColor or props.textColor,
		TextSize = 18,
		TextScaled = true,
		Font = Enum.Font.Arcade,
		TextXAlignment = props.textXAlignment or Enum.TextXAlignment.Left,
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
