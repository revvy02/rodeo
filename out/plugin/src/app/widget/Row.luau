local React = require(script.Parent.Parent.Parent.Parent:WaitForChild('packages'):WaitForChild('react'))

local e = React.createElement

export type Props = {
	height: number?,
	layoutOrder: number?,
	children: any,
}

local function Row(props: Props)
	local height = props.height or 24

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = props.layoutOrder,
	}, {
		Layout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Children = e(React.Fragment, nil, props.children),
	})
end

return Row
