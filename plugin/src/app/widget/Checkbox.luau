local React = require("@pkg/react")
local constants = require(script.Parent.Parent.Parent.library.constants)
local Button = require(script.Parent.Button)

local e = React.createElement
local COLORS = constants.COLORS

export type Props = {
	checked: boolean,
	strokeColor: Color3,
	onToggle: () -> (),
}

local function Checkbox(props: Props)
	local color = if props.checked then COLORS.success else COLORS.error
	local digit = if props.checked then "1" else "0"

	return e(Button, {
		text = digit,
		color = color,
		strokeColor = props.strokeColor,
		size = UDim2.fromOffset(24, 24),
		cornerRadius = 4,
		layoutOrder = 2,
		onClick = props.onToggle,
	})
end

return Checkbox
