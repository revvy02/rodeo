local React = require("@pkg/react")

local e = React.createElement

export type Props = {
	text: string,
	color: Color3,
	strokeColor: Color3,
	backgroundColor: Color3,
	hoverBackgroundColor: Color3,
	layoutOrder: number?,
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

	return e("TextButton", {
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(140, 50),
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = props.onClick,
		[React.Event.MouseEnter] = handleMouseEnter,
		[React.Event.MouseLeave] = handleMouseLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),
		Stroke = e("UIStroke", {
			Color = props.strokeColor,
			Thickness = 1,
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
