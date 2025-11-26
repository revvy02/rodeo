local React = require(script.Parent.Parent.Parent.Parent:WaitForChild('packages'):WaitForChild('react'))

local e = React.createElement

export type Props = {
	text: string,
	color: Color3,
	backgroundColor: Color3,
	hoverBackgroundColor: Color3,
	onClick: () -> (),
}

local function Button(props: Props)
	local isHovering, setIsHovering = React.useState(false)

	local function handleMouseEnter()
		setIsHovering(true)
	end

	local function handleMouseLeave()
		setIsHovering(false)
	end

	local backgroundColor = if isHovering then props.hoverBackgroundColor else props.backgroundColor
	local strokeThickness = if isHovering then 2 else 1.5

	return e("TextButton", {
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(140, 50),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Text = "",
		[React.Event.Activated] = props.onClick,
		[React.Event.MouseEnter] = handleMouseEnter,
		[React.Event.MouseLeave] = handleMouseLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = props.color,
			Thickness = strokeThickness,
			Transparency = 0,
		}, {
			StrokeGradient = e("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, if isHovering then 0 else 0.2),
					NumberSequenceKeypoint.new(0.5, 0),
					NumberSequenceKeypoint.new(1, if isHovering then 0 else 0.2),
				}),
				Rotation = 90,
			}),
		}),
		Label = e("TextLabel", {
			Text = props.text,
			TextColor3 = props.color,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.Arcade,
			TextSize = 16,
			TextScaled = true,
		}, {
			TextSizeConstraint = e("UITextSizeConstraint", {
				MaxTextSize = 16,
				MinTextSize = 10,
			}),
			Gradient = e("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, props.color),
					ColorSequenceKeypoint.new(1, Color3.new(
						props.color.R * 0.7,
						props.color.G * 0.7,
						props.color.B * 0.7
					)),
				}),
				Rotation = 90,
			}),
		}),
	})
end

return Button
