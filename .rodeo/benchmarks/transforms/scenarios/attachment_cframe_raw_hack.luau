--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/attachment_cframe_hack --target run:server

-- Benchmark: Attachment.CFrame via raw property setter (xpcall hack) with N attachments

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
local CFRAME = "CFrame"

local config = require("../config")

local N = config.N
local FRAMES = config.FRAMES

-- Setup: create N attachments on Terrain
local attachments = table.create(N)

for i = 1, N do
	local attachment = Instance.new("Attachment")
	attachment.Name = "Root"
	attachment.Visible = true
	attachment.Parent = workspace.Terrain
	attachments[i] = attachment
end

-- Run
for frame = 1, FRAMES do
	debug.profilebegin("transform")
	for i = 1, N do
		PROPERTY_SET(
			attachments[i],
			CFRAME,
			CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
		)
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
