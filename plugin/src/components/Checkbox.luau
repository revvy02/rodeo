local React = require(script.Parent.Parent.Parent.packages.react)
local constants = require(script.Parent.Parent.constants)

local e = React.createElement
local COLORS = constants.COLORS

local function colorToHex(color: Color3): string
	return string.format("%02X%02X%02X",
		math.floor(color.R * 255),
		math.floor(color.G * 255),
		math.floor(color.B * 255)
	)
end

export type Props = {
	checked: boolean,
	strokeColor: Color3,
	onToggle: () -> (),
}

local function Checkbox(props: Props)
	local color = if props.checked then COLORS.success else COLORS.error
	local hex = colorToHex(color)
	local digit = if props.checked then "1" else "0"
	local richText = `<font color="#{hex}">{digit}</font>`

	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
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
			Label = e("TextLabel", {
				Text = richText,
				RichText = true,
				TextColor3 = COLORS.text,
				TextSize = 18,
				Font = Enum.Font.Arcade,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return Checkbox
