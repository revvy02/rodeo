local React = require("@pkg/react")

local e = React.createElement

export type Props = {
	text: string,
	color: Color3,
	strokeColor: Color3,
	size: UDim2,
	cornerRadius: number?,
	layoutOrder: number?,
	onClick: () -> (),
}

local function Button(props: Props)
	local cornerRadius = props.cornerRadius or 8
	local isPressed, setIsPressed = React.useState(false)

	local function handleMouseButton1Down()
		setIsPressed(true)
	end

	local function handleMouseButton1Up()
		setIsPressed(false)
	end

	local function handleMouseLeave()
		setIsPressed(false)
	end

	local textColor = if isPressed then Color3.fromRGB(255, 255, 255) else props.color
	local strokeColor = if isPressed then Color3.fromRGB(255, 255, 255) else props.strokeColor

	return e("TextButton", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0,
		AutoButtonColor = true,
		Size = props.size,
		Text = "",
		LayoutOrder = props.layoutOrder,
		[React.Event.Activated] = props.onClick,
		[React.Event.MouseButton1Down] = handleMouseButton1Down,
		[React.Event.MouseButton1Up] = handleMouseButton1Up,
		[React.Event.MouseLeave] = handleMouseLeave,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(0, cornerRadius),
		}),
		Stroke = e("UIStroke", {
			Color = strokeColor,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		Label = e("TextLabel", {
			Text = props.text,
			TextColor3 = textColor,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Font = Enum.Font.Arcade,
			TextSize = 18,
			TextScaled = true,
		}, {
			TextSizeConstraint = e("UITextSizeConstraint", {
				MaxTextSize = 20,
				MinTextSize = 10,
			}),
		}),
	})
end

return Button
