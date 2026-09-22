-- @rodeo run --place --save ./.rodeo/map/town.rbxl
--
-- Builds a small deterministic town in an empty place; rodeo saves the result
-- to .rodeo/map/town.rbxl when the run ends (the --save in the directive).
-- renderMap.luau opens that file and captures it from above. Run this first,
-- from the repo root (the directive paths are relative to the cwd):
--
--   rodeo run .rodeo/map/buildMap.luau
--   rodeo run .rodeo/map/renderMap.luau

local Lighting = game:GetService("Lighting")
local rng = Random.new(42)

-- The template's floor and spawn would show around the town's edge.
for _, name in { "Baseplate", "SpawnLocation" } do
	local existing = workspace:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

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
	return p
end

local town = Instance.new("Folder")
town.Name = "Town"
town.Parent = workspace

-- 512 x 512 studs of ground.
local HALF = 256
part("Ground", Vector3.new(2 * HALF, 1, 2 * HALF), CFrame.new(0, 0.5, 0), Color3.fromRGB(92, 140, 70), Enum.Material.Grass).Parent = town

-- Road grid every 64 studs.
for i = -HALF, HALF, 64 do
	part("RoadNS", Vector3.new(12, 1.2, 2 * HALF), CFrame.new(i, 1, 0), Color3.fromRGB(70, 70, 74), Enum.Material.Asphalt).Parent = town
	part("RoadEW", Vector3.new(2 * HALF, 1.2, 12), CFrame.new(0, 1, i), Color3.fromRGB(70, 70, 74), Enum.Material.Asphalt).Parent = town
end

-- Two to four buildings per block, except the park block and the lake blocks.
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

-- A lake over the south-west blocks.
local lake = part("Lake", Vector3.new(1.4, 110, 110), CFrame.new(-150, 1.1, 150) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 120, 200))
lake.Shape = Enum.PartType.Cylinder
lake.Parent = town

-- Flat, even light for a map: noon, no long shadows, no haze at map-camera distances.
Lighting.ClockTime = 12
Lighting.GlobalShadows = false
Lighting.Brightness = 2
Lighting.FogEnd = 100000
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density = 0
end

print(`built {#town:GetChildren()} parts; rodeo saves the place to .rodeo/map/town.rbxl on exit`)
