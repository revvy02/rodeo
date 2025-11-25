--[[
	Rodeo Test Suite

	Running tests:
		- Automated tests only: lune run test/rodeo.test.luau
		- Full suite with Studio: RODEO_SKIP_STUDIO_TESTS=0 lune run test/rodeo.test.luau

	Manual test setup (for exec/serve tests):
		1. Terminal 1: rodeo build && rodeo serve
		2. Terminal 2: Open Roblox Studio, enable rodeo plugin
		3. Terminal 3: RODEO_SKIP_STUDIO_TESTS=0 lune run test/rodeo.test.luau

	Test categories:
		- Automated: exec failure, once mode
		- Manual: exec with server, queuing behavior
]]

local process = require("@lune/process")
local task = require("@lune/task")
local testkit = require("./testkit")

local it = testkit.test()
local TEST, CASE = it.TEST, it.CASE
local CHECK, FINISH, SKIP = it.CHECK, it.FINISH, it.SKIP

-- Skip Studio-dependent tests by default (can be enabled with RODEO_SKIP_STUDIO_TESTS=0)
local SKIP_STUDIO_TESTS = process.env.RODEO_SKIP_STUDIO_TESTS ~= "0"

TEST("exec request drops if no server", function()
	local exec_process = process.exec("rodeo exec")
	CHECK(exec_process.code == 1)
end)

TEST("exec request runs if server running and nothing in front", function()
	-- NOTE: This test requires a Studio instance connected to rodeo serve
	-- To run manually:
	-- Terminal 1: rodeo build && rodeo serve
	-- Terminal 2: Open Studio and connect the rodeo plugin
	-- Terminal 3: RODEO_SKIP_STUDIO_TESTS=0 lune run test/rodeo.test.luau

	if SKIP_STUDIO_TESTS then
		SKIP()
		return
	end

	-- Verify server health
	local status_result = process.exec("rodeo status")
	CHECK(status_result.code == 0)

	-- Execute simple script
	local exec_result = process.exec("rodeo exec ./test/fixtures/simple_print.luau")

	CASE("execution succeeds")
	CHECK(exec_result.code == 0)

	CASE("output contains expected text")
	CHECK(string.find(exec_result.stdout, "Hello from rodeo") ~= nil)
end)

TEST("exec request queues if server running", function()
	-- NOTE: This test requires a Studio instance connected to rodeo serve
	-- See previous test for setup instructions

	if SKIP_STUDIO_TESTS then
		SKIP()
		return
	end

	-- Submit long-running script (will occupy Studio)
	local exec1_process = process.spawn("rodeo", { "exec", "./test/fixtures/long_running.luau" })

	-- Brief delay to ensure first exec is active
	task.wait(0.5)

	-- Submit second script (should queue)
	local exec2_result = process.exec("rodeo exec ./test/fixtures/simple_print.luau")

	-- Wait for first to complete
	local exec1_result = exec1_process:wait()

	CASE("first execution completes")
	CHECK(exec1_result.code == 0)

	CASE("second execution completes")
	CHECK(exec2_result.code == 0)
end)

TEST("once should pipe output back to console", function()
	local once_process = process.exec("rodeo once ./test/once/test.luau --place ./test/once/place.rbxlx")

	CASE("exits successfully")
	CHECK(once_process.code == 0)

	CASE("outputs expected text")
	CHECK(string.find(once_process.stdout, "Test once execution") ~= nil)
end)
