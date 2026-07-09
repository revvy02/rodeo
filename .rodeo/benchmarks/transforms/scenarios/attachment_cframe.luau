--@rodeo run --place --focus --profile .rodeo/benchmarks/transforms/results/profiles/attachment_cframe --context server

-- Benchmark: Attachment.CFrame with N attachments

local RunService = game:GetService("RunService")

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
		attachments[i].CFrame = CFrame.new(math.random(-100, 100), math.random(-100, 100), math.random(-100, 100))
	end
	debug.profileend()
	RunService.PreSimulation:Wait()
end

return "done"
