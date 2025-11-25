local React = require(script.Parent.Parent.Parent.packages.react)
local RunService = game:GetService("RunService")
local assets = require(script.Parent.Parent.assets)

local e = React.createElement

local TILE_SIZE = 40

local function RodeoLabel()
	local imageRef = React.useRef(nil :: ImageLabel?)
	local offset, setOffset = React.useState(0)

	React.useEffect(function()
		local connection = RunService.Heartbeat:Connect(function(dt)
			setOffset(function(current)
				return (current + dt * 20) % TILE_SIZE
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local image = imageRef.current
		if image then
			image.ImageRectOffset = Vector2.new(offset, 0)
		end
	end, { offset })

	return e("ImageLabel", {
		ref = imageRef,
		Image = assets.rodeo,
		ImageColor3 = Color3.fromRGB(255, 70, 80),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 0,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(TILE_SIZE, 40),
		ImageRectSize = Vector2.new(TILE_SIZE, 40),
		ImageRectOffset = Vector2.new(0, 0),
	})
end

return RodeoLabel
