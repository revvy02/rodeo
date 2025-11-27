local React = require("@pkg/react")
local useAppContext = require(script.Parent.Parent.context.AppContext).useAppContext
local Row = require(script.Parent.Row)
local constants = require(script.Parent.Parent.Parent.constants)

local e = React.createElement
local COLORS = constants.COLORS

-- Count number of entries in CONTEXT_BITS table
local NUM_CONTEXT_BITS = 0
for _ in constants.CONTEXT_BITS do
	NUM_CONTEXT_BITS += 1
end

-- Build rich text string from context bitset
-- Shows 1 (green) when active, 0 (red) when inactive
-- Works with any size bitset
local function buildContextRichText(bitset: number, numBits: number): string
	local parts = {}
	for i = 0, numBits - 1 do
		local active = bit32.band(bitset, bit32.lshift(1, i)) ~= 0
		local color = if active then COLORS.success else COLORS.error
		local hex = color:ToHex()
		local digit = if active then "1" else "0"
		table.insert(parts, `<font color="#{hex}">{digit}</font>`)
	end

	return table.concat(parts, "")
end

local function StatusIndicator()
	local context = useAppContext()
	local connected = context.connected
	local isExecuting = context.isExecuting
	local status = context.status

	-- Dot color: yellow when executing, green when connected, red when disconnected
	local dotColor = if isExecuting then COLORS.executing
		elseif connected then COLORS.success
		else COLORS.error

	local contextText = buildContextRichText(context.contextBitset, NUM_CONTEXT_BITS)

	return e(Row, {
		height = 24,
		layoutOrder = 1,
	}, {
		Left = e("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.7, 1),
			LayoutOrder = 1,
		}, {
			Layout = e("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
			}),
			Dot = e("Frame", {
				BackgroundColor3 = dotColor,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(10, 10),
				LayoutOrder = 1,
			}, {
				Corner = e("UICorner", {
					CornerRadius = UDim.new(1, 0),
				}),
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = status,
				RichText = true,
				TextColor3 = COLORS.text,
				TextSize = 18,
				TextScaled = true,
				Font = Enum.Font.Arcade,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}, {
				TextSizeConstraint = e("UITextSizeConstraint", {
					MaxTextSize = 18,
					MinTextSize = 12,
				}),
			}),
		}),
		ContextBits = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
		}, {
			Padding = e("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingRight = UDim.new(0, 6),
			}),
			Corner = e("UICorner", {
				CornerRadius = UDim.new(0, 4),
			}),
			Stroke = e("UIStroke", {
				Color = COLORS.stroke,
				Thickness = 1,
			}),
			Label = e("TextLabel", {
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				Text = contextText,
				RichText = true,
				TextColor3 = COLORS.text,
				TextSize = 20,
				Font = Enum.Font.Arcade,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}),
	})
end

return StatusIndicator
