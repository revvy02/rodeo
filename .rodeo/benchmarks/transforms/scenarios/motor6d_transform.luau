--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/motor6d_transform --target run:server

-- Benchmark: Motor6D.Transform with N constraints
-- Runs for ~10s at 60fps, profiler captures engine-level frame data

local RunService = game:GetService("RunService")

local config = require("../config")

local N = config.N
local FRAMES = config.FRAMES

-- Setup: root part + N child parts connected via Motor6D
local root = Instance.new("Part")
root.Name = "Root"
root.Anchored = true
root.Parent = workspace
root.CFrame = CFrame.identity

local motor6ds = table.create(N) :: { Motor6D }
local child_parts = table.create(N) :: { Part }

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

for _ = 1, FRAMES do
	debug.profilebegin("transform")
	for i = 1, N do
		motor6ds[i].Transform = CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
