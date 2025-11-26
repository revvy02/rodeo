local React = require(script.Parent.Parent.Parent.packages.react)

local e = React.createElement

export type Props = {
	checked: boolean,
	strokeColor: Color3,
	accentColor: Color3,
	onToggle: () -> (),
}

local function Checkbox(props: Props)
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
			Color = props.strokeColor,
			Thickness = 1,
		}),
		Button = e("TextButton", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromOffset(0, 0),
			Text = "",
			[React.Event.Activated] = props.onToggle,
		}, {
			Checkmark = e("TextLabel", {
				Text = if props.checked then "✓" else "",
				TextColor3 = props.accentColor,
				TextSize = 18,
				Font = Enum.Font.Arcade,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return Checkbox
