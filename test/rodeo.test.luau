local process = require("@lune/process")
local testkit = require("testkit")

local it = testkit.test()
local TEST, CASE = it.TEST, it.CASE
local CHECK, FINISH = it.CHECK, it.FINISH

TEST("exec request drops if no server", function()
	local exec_process = process.exec("rodeo exec")
	CHECK(exec_process.code == 1)
end)

TEST("exec request runs if server running and nothing in front", function() end)

TEST("exec request queues if server running", function() end)

TEST("exec request runs if server running and nothing in front", function() end)

TEST("exec request runs if server running and nothing in front", function() end)

TEST("once should pipe output back to console", function()
	local once_process = process.exec("rodeo once --path ./test/once")
	CHECK(once_process.code == 0)
end)
