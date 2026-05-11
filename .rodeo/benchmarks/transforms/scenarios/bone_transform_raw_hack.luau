--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/bone_transform_hack --target run:server:plugin

-- Benchmark: Bone.Transform via raw property setter (xpcall hack) with N bones

local RunService = game:GetService("RunService")

-- Extract the raw C __newindex function for Instance by triggering an error
local PROPERTY_SET
do
	local dummy = Instance.new("Part")
	xpcall(function()
		dummy[nil] = nil
	end, function()
		PROPERTY_SET = debug.info(2, "f")
	end)
	dummy:Destroy()
end
local TRANSFORM = "Transform"

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
		PROPERTY_SET(
			bones[i],
			TRANSFORM,
			CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		)
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
