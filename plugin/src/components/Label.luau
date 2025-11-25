local React = require(script.Parent.Parent.Parent.packages.react)
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext

local e = React.createElement

export type Props = {
	text: string,
}

local function Label(props: Props)
	local context = useAppContext()

	return e("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY,
		Text = props.text,
		TextColor3 = context.COLORS.accent,
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
