--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/bulkmoveto_hack --target run:server

-- Benchmark: workspace:BulkMoveTo() via raw method call (xpcall hack) with N anchored parts

local RunService = game:GetService("RunService")

-- Extract the raw C method function for BulkMoveTo by triggering an error
local BULK_MOVE_TO
do
	xpcall(function()
		workspace:BulkMoveTo(task)
	end, function()
		BULK_MOVE_TO = debug.info(2, "f")
	end)
end

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
	BULK_MOVE_TO(workspace, parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
