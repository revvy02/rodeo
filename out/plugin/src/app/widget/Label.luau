local React = require(script.Parent.Parent.Parent.Parent:WaitForChild('packages'):WaitForChild('react'))

local e = React.createElement

export type Props = {
	text: string,
	textColor: Color3?,
}

local function Label(props: Props)
	return e("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Text = props.text,
		TextColor3 = props.textColor or Color3.fromRGB(255, 70, 80),
		TextSize = 20,
		Font = Enum.Font.Arcade,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
	}, {
		Gradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 130)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 70)),
			}),
			Rotation = 90,
		}),
	})
end

return Label
