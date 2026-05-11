--!strict
--[[
	mode_driver.luau — plugin-side convergence loop. Backend broadcasts
	target_mode to every VM in a studio; each plugin retries its role-
	appropriate action in a loop until its own mode satisfies the target
	(or a new target arrives and supersedes this one).

	Role dispatch:
	- Edit VM (IsEdit) enters a session: ExecuteRunModeAsync / ExecutePlayModeAsync.
	- Server VM (IsServer, not edit) exits: EndTest.
	- Client VMs: no-op.

	Each setTarget bumps a token; the running loop checks the token each
	iteration and exits if the target was superseded.
]]

local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")

local studio = require(script.Parent.studio)

local isEdit = RunService:IsEdit()
local isServer = RunService:IsServer()

local RETRY_INTERVAL = 1

local currentTarget: string? = nil
local token = 0

local function matches(ownMode: string, target: string): boolean
	if target == ownMode then
		return true
	end
	-- test vs play is a post-hoc MCP-reconciliation distinction; both satisfy
	-- either target since Studio itself has entered the same play DataModel.
	if (target == "test" or target == "play") and (ownMode == "test" or ownMode == "play") then
		return true
	end
	return false
end

-- Whether this plugin still has work to do for the current target.
local function needsAction(): boolean
	local target = currentTarget
	if target == nil or target == "" then
		return false
	end
	if isEdit then
		-- Edit VM always reports mode="edit". If target is anything other than
		-- edit, we need to fire the enter script. If the studio happens to
		-- already be in that mode, Roblox will reject the call and pcall
		-- swallows — harmless spin.
		return target ~= "edit"
	end
	if isServer then
		local state = studio.getState()
		if not state then
			return false
		end
		return not matches(state.mode, target)
	end
	return false
end

local function fire()
	local target = currentTarget
	if target == nil or target == "" then
		return
	end
	if isEdit then
		if target == "run" then
			task.spawn(function()
				pcall(StudioTestService.ExecuteRunModeAsync, StudioTestService, true)
			end)
		elseif target == "test" or target == "play" then
			task.spawn(function()
				pcall(StudioTestService.ExecutePlayModeAsync, StudioTestService, true)
			end)
		end
	elseif isServer then
		task.spawn(function()
			pcall(StudioTestService.EndTest, StudioTestService, "end_test")
		end)
	end
end

local function loop(myToken: number)
	while token == myToken and needsAction() do
		fire()
		task.wait(RETRY_INTERVAL)
	end
end

local function setTarget(target: string?)
	currentTarget = target
	token += 1
	local myToken = token
	task.spawn(loop, myToken)
end

return {
	setTarget = setTarget,
}
