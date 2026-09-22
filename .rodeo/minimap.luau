-- @rodeo run --place
--
-- Minimap demo: build a small town in an empty place, then capture it from
-- straight above as a square top-down map. Everything is hardcoded so this
-- runs as-is with `rodeo run .rodeo/minimap.luau`; change the constants below
-- to point the camera at your own place (swap the directive for
-- `-- @rodeo run --place ./your-place.rbxl` and drop the town-building part).
--
-- Roblox has no orthographic camera, so the map is a narrow-FOV perspective
-- shot from high up: at FOV 10 the visible span is about 0.175 x height, so a
-- 3000-stud camera sees roughly 525 studs across, a little more than the
-- 512-stud town. A square viewport keeps the map square.

local roblox = require("@rodeo/roblox")

-- Camera: straight down over the town center, north (-Z) at the top of the image.
local MAP_CENTER = Vector3.new(0, 0, 0)
local CAMERA_HEIGHT = 3000
local CFRAME = CFrame.lookAt(MAP_CENTER + Vector3.new(0, CAMERA_HEIGHT, 0), MAP_CENTER, Vector3.new(0, 0, -1))
local FOV = 10
local FOCUS = CFrame.new(MAP_CENTER)
local SIZE = Vector2.new(4096, 4096)
local OUTPUT = ".rodeo/.temp/captures/minimap.png"

-- Town: deterministic, 512 x 512 studs.
local Lighting = game:GetService("Lighting")
local rng = Random.new(42)

local function part(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.Parent = workspace
	return p
end

local town = Instance.new("Folder")
town.Name = "MinimapTown"
town.Parent = workspace

local HALF = 256
part("Ground", Vector3.new(2 * HALF, 1, 2 * HALF), CFrame.new(0, 0.5, 0), Color3.fromRGB(92, 140, 70), Enum.Material.Grass).Parent = town

-- Road grid every 64 studs.
for i = -HALF, HALF, 64 do
	part("RoadNS", Vector3.new(12, 1.2, 2 * HALF), CFrame.new(i, 1, 0), Color3.fromRGB(70, 70, 74), Enum.Material.Asphalt).Parent = town
	part("RoadEW", Vector3.new(2 * HALF, 1.2, 12), CFrame.new(0, 1, i), Color3.fromRGB(70, 70, 74), Enum.Material.Asphalt).Parent = town
end

-- Buildings inside each block, skipping the park and lake blocks.
local palette = {
	Color3.fromRGB(196, 96, 80), Color3.fromRGB(214, 174, 96), Color3.fromRGB(120, 140, 200),
	Color3.fromRGB(160, 160, 170), Color3.fromRGB(230, 220, 200), Color3.fromRGB(110, 80, 70),
}
for bx = -HALF + 32, HALF - 32, 64 do
	for bz = -HALF + 32, HALF - 32, 64 do
		local isPark = bx == 96 and bz == -96
		local isLake = bx <= -96 and bz >= 96
		if isPark then
			part("Park", Vector3.new(50, 1.4, 50), CFrame.new(bx, 1.1, bz), Color3.fromRGB(60, 170, 90), Enum.Material.Grass).Parent = town
		elseif not isLake then
			for _ = 1, rng:NextInteger(2, 4) do
				local w, d = rng:NextInteger(10, 22), rng:NextInteger(10, 22)
				local h = rng:NextInteger(8, 60)
				local x = bx + rng:NextNumber(-20 + w / 2, 20 - w / 2)
				local z = bz + rng:NextNumber(-20 + d / 2, 20 - d / 2)
				part("Building", Vector3.new(w, h, d), CFrame.new(x, 1 + h / 2, z), palette[rng:NextInteger(1, #palette)], Enum.Material.Concrete).Parent = town
			end
		end
	end
end

-- Lake in the south-west corner blocks.
local lake = part("Lake", Vector3.new(1.4, 110, 110), CFrame.new(-150, 1.1, 150) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 120, 200), Enum.Material.Glass)
lake.Shape = Enum.PartType.Cylinder
lake.Parent = town

-- Flat, even light: noon, no long shadows, no haze at 3000 studs.
Lighting.ClockTime = 12
Lighting.GlobalShadows = false
Lighting.Brightness = 2
Lighting.FogEnd = 100000
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0
end

local path, info = roblox.captureViewport(OUTPUT, {
	cframe = CFRAME,
	fov = FOV,
	focus = FOCUS,
	viewportSize = SIZE,
	settle = 3,
})
print(`minimap: {info.width}x{info.height} -> {path}`)
return path
