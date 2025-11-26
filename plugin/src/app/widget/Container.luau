local React = require("@pkg/react")

local e = React.createElement

export type Props = {
	children: { [string]: any },
}

local function Container(props: Props)
	return e("Frame", {
		BackgroundColor3 = Color3.fromRGB(8, 6, 5),
		BackgroundTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, {
		Padding = e("UIPadding", {
			PaddingTop = UDim.new(0, 20),
			PaddingBottom = UDim.new(0, 20),
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
		}),
		ListLayout = e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			Padding = UDim.new(0, 15),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Children = e(React.Fragment, nil, props.children),
	})
end

return Container
