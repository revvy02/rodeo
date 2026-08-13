--!strict
--[[
	mode_driver.luau — plugin-side convergence loop. Backend broadcasts
	target_mode to every DOM in a studio; each plugin retries its role-
	appropriate action in a loop until its own mode satisfies the target
	(or a new target arrives and supersedes this one).

	Role dispatch:
	- Edit DOM (IsEdit) enters a session: ExecuteRunModeAsync / ExecutePlayModeAsync.
	- Server DOM (IsServer, not edit) exits: EndTest.
	- Client DOMs: no-op.

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
		-- Edit DOM always reports mode="edit". If target is anything other than
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

-- One session call in flight at a time.
--
-- Execute*ModeAsync does NOT error when a session is already running: during a
-- run session it BLOCKS, and only resolves (into nothing) once that session
-- ends. So a run->play transition — the one transition needing both an end and
-- a start — used to stack one blocked start per retry against the server DOM's
-- concurrent EndTest, until a session was half-started and immediately killed.
-- That leaves StudioTestService believing a test is in progress with no server
-- DataModel left to EndTest it: the studio can never enter play again.
--
-- Serialized, the transition sequences itself: the first start blocks, EndTest
-- tears the old session down, the blocked call is discarded, and the next retry
-- starts cleanly against an idle studio.
local inFlight = false

local function spawnCall(what: string, fn, ...)
	if inFlight then
		return
	end
	inFlight = true
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(fn, table.unpack(args, 1, args.n))
		inFlight = false
		if not ok then
			-- Never swallow: this failure mode was invisible for exactly this
			-- reason, and the retry loop hides transient errors anyway.
			warn(`[rodeo] mode_driver {what} failed: {err}`)
		end
	end)
end

local function fire()
	local target = currentTarget
	if target == nil or target == "" then
		return
	end
	if isEdit then
		if target == "run" then
			spawnCall("ExecuteRunModeAsync", StudioTestService.ExecuteRunModeAsync, StudioTestService, true)
		elseif target == "test" or target == "play" then
			spawnCall("ExecutePlayModeAsync", StudioTestService.ExecutePlayModeAsync, StudioTestService, true)
		end
	elseif isServer then
		spawnCall("EndTest", StudioTestService.EndTest, StudioTestService, "end_test")
	end
end

-- TEMPORARY WORKAROUND for a Studio engine bug — remove once Roblox fixes it.
--
-- The bug: StudioTestService:ExecutePlayModeAsync fired at the instant a
-- previous session is tearing down NEVER RETURNS and never starts play. It
-- does not error, does not time out, does not queue — the call is simply lost,
-- and the studio is left unable to enter play mode until it is restarted.
-- Measured on Studio 0.734.0.7340915 with a controlled 2x2, fresh studio per
-- trial:
--
--   teardown + 1s, no prior failed call  -> play starts
--   teardown + 1s, prior failed call     -> play starts
--   teardown + 0s                        -> blocks forever, no session (n=2)
--
-- Timing is the only variable. rodeo hits it every time because the master
-- re-pushes the target the moment the server DOM disconnects, which is exactly
-- that instant, so run<->play transitions hung ~60s and bricked the studio.
--
-- The workaround: the edit DOM waits before its FIRST start attempt for a
-- target, so the call lands after teardown settles. The server DOM's EndTest
-- has no such hazard and still fires immediately. Cost: ~1s added to every
-- transition that starts a session.
--
-- To check whether Roblox has fixed it: enter run mode, call EndTest from the
-- server DataModel, and immediately (no delay) call ExecutePlayModeAsync from
-- the edit DataModel. If play mode starts, the bug is gone — delete
-- SETTLE_BEFORE_START and the `first and isEdit` branch in loop() below. The
-- in-flight guard above is worth keeping regardless: it is ordinary hygiene
-- for an async call that blocks rather than erroring while a session is live.
local SETTLE_BEFORE_START = 1

local function loop(myToken: number)
	local first = true
	while token == myToken and needsAction() do
		if first and isEdit then
			task.wait(SETTLE_BEFORE_START)
			if token ~= myToken or not needsAction() then
				return
			end
		end
		first = false
		fire()
		task.wait(RETRY_INTERVAL)
	end
end

local function setTarget(target: string?)
	currentTarget = target
	token += 1
	-- A *successful* Execute*ModeAsync also blocks — it yields for the whole
	-- lifetime of the session it started — so the in-flight flag would stay set
	-- for as long as the studio is in that mode. A new target means a genuinely
	-- new attempt is warranted, so release it here; otherwise the next
	-- transition would find this DOM permanently guarded.
	inFlight = false
	local myToken = token
	task.spawn(loop, myToken)
end

return {
	setTarget = setTarget,
}
