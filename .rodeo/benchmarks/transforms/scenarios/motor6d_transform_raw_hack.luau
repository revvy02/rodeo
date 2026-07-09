--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/motor6d_transform_hack --context server

-- Benchmark: Motor6D.Transform via raw property setter (xpcall hack) with N constraints
-- Uses chax rawcall to bypass normal property setter overhead

local RunService = game:GetService("RunService")

-- Extract the raw C __newindex function for Instance by triggering an error
-- xpcall catches the error, but the C function is returned via the error handler
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

local config = require("../config")

local N = config.N
local FRAMES = config.FRAMES

-- Setup: root part + N child parts connected via Motor6D
local root = Instance.new("Part")
root.Name = "Root"
root.Anchored = true
root.Parent = workspace
root.CFrame = CFrame.identity

local motor6ds = table.create(N)
local child_parts = table.create(N)

for i = 1, N do
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanQuery = false
	part.CanCollide = false
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Parent = workspace

	local motor6d = Instance.new("Motor6D")
	motor6d.Name = "Root"
	motor6d.Part0 = root
	motor6d.Part1 = part
	motor6d.Parent = part

	motor6ds[i] = motor6d
	child_parts[i] = part
end

-- Run
for frame = 1, FRAMES do
	debug.profilebegin("transform")
	for i = 1, N do
		PROPERTY_SET(
			motor6ds[i],
			TRANSFORM,
			CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		)
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
