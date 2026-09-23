-- @lute/task conformance, per submodules/lute/definitions/task.luau.
local task = require("@lute/task")
local time = require("@lute/time")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

-- wait returns elapsed and accepts Durations
local waited = task.wait(0.05)
check(type(waited) == "number" and waited >= 0.05, "wait(number) wrong")
local waitedDur = task.wait(time.duration.milliseconds(50))
check(waitedDur >= 0.05, "wait(Duration) wrong")

-- spawn runs immediately; defer runs after the current thread yields
local order = {}
task.spawn(function()
	table.insert(order, "spawn")
end)
check(order[1] == "spawn", "spawn did not run immediately")
task.defer(function()
	table.insert(order, "defer")
end)
check(#order == 1, "defer ran before yield")
task.wait()
check(order[2] == "defer", "defer did not run after yield")

-- resume drives a plain coroutine and returns the thread
local resumed = false
local co = coroutine.create(function()
	resumed = true
end)
check(task.resume(co) == co, "resume should return the thread")
check(resumed, "resume did not run the thread")

-- delay schedules later, accepts Durations
local fired = false
task.delay(time.duration.milliseconds(30), function()
	fired = true
end)
check(not fired, "delay fired synchronously")
task.wait(0.1)
check(fired, "delay never fired")

-- deferSelf yields and reschedules the current thread
local progressed = false
task.spawn(function()
	task.deferSelf()
	progressed = true
end)
check(not progressed, "deferSelf did not yield")
task.wait()
check(progressed, "deferSelf never resumed")

return true
