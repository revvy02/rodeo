--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/bulkmoveto --context server

-- Benchmark: workspace:BulkMoveTo() with N anchored parts
-- Runs for ~10s at 60fps, profiler captures engine-level frame data

local RunService = game:GetService("RunService")

local config = require("../config")

local N = config.N
local FRAMES = config.FRAMES

-- Setup
local parts = table.create(N)
for i = 1, N do
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanQuery = false
	part.CanCollide = false
	part.Color = Color3.fromRGB(0, 0, 255)
	part.Parent = workspace
	parts[i] = part
end

-- Run
for frame = 1, FRAMES do
	debug.profilebegin("transform")
	local cframes = table.create(N)
	for i = 1, N do
		cframes[i] = CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
	end
	workspace:BulkMoveTo(parts, cframes)
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
