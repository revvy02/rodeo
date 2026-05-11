--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/bone_transform --target run:server:plugin

local RunService = game:GetService("RunService")

local bonePrefab = require("@rodeo/roblox").load(".rodeo/benchmarks/transforms/assets/bone_part.rbxm")[1]

local config = require("../config")

local N = config.N
local FRAMES = config.FRAMES

-- Setup: clone BonePart prefab N times, extract the Root bone
local bones = table.create(N)
local cleanup_parts = table.create(N)

for i = 1, N do
	local part = bonePrefab:Clone()
	part.Parent = workspace
	bones[i] = part.Root
	cleanup_parts[i] = part
end

-- Run
for frame = 1, FRAMES do
	debug.profilebegin("transform")
	for i = 1, N do
		bones[i].Transform = CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
