local React = require("@pkg/react")
local TweenService = game:GetService("TweenService")
local assets = require(script.Parent.Parent.Parent.library.assets)
local constants = require(script.Parent.Parent.Parent.library.constants)

local e = React.createElement

local TILE_SIZE_X = 140
local TILE_SIZE_Y = 40

local function RodeoLabel()
	local imageRef, setImageRef = React.useState(nil :: ImageLabel?)

	React.useEffect(function()
		if not imageRef then
			return
		end

		-- Create tween info for smooth continuous animation
		-- Move by exactly one tile size so it loops seamlessly
		local tweenInfo = TweenInfo.new(
			2, -- Duration in seconds (adjust for speed)
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.InOut,
			-1, -- Repeat infinitely
			false, -- Don't reverse
			0 -- No delay
		)

		-- Tween from 0 to -TILE_SIZE pixels (one tile width)
		local tween = TweenService:Create(imageRef, tweenInfo, {
			Position = UDim2.fromOffset(-TILE_SIZE_X, 0),
		})

		tween:Play()

		return function()
			tween:Cancel()
		end
	end, { imageRef })

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(2, 0, 0, TILE_SIZE_Y),
		LayoutOrder = 0,
	}, {
		Stroke = e("UIStroke", {
			Color = constants.COLORS.stroke,
			Thickness = 2,
			Transparency = 0,
		}, {
			Gradient = e("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.7),
					NumberSequenceKeypoint.new(0.5, 0.3),
					NumberSequenceKeypoint.new(1, 0.7),
				}),
				Rotation = 0,
			}),
		}),
		ImageLabel = e("ImageLabel", {
			ref = setImageRef,
			Image = assets.logo,
			ImageColor3 = Color3.fromRGB(255, 70, 80),
			BackgroundTransparency = 1,
			Size = UDim2.new(1, TILE_SIZE_X, 0, TILE_SIZE_Y),
			Position = UDim2.new(0, 0, 0, 0),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(TILE_SIZE_X, TILE_SIZE_Y),
		}),
	})
end

return RodeoLabel
