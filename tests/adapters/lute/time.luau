-- @lute/time conformance, per submodules/lute/definitions/time.luau.
local task = require("@lute/task")
local time = require("@lute/time")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

-- Instants: now/since/elapsed, ordering, subtraction to Duration
local a = time.now()
task.wait(0.05)
local b = time.now()
check(a < b, "later instant should compare greater")
check(time.since(a) >= 0.05, "since under-reports")
check(a:elapsed() >= 0.05, "elapsed under-reports")
local delta = b - a
check(delta:toSeconds() >= 0.05, "instant subtraction wrong")

-- Duration constructors and conversions
check(time.duration.seconds(1):toMilliseconds() == 1000, "seconds->ms wrong")
check(time.duration.milliseconds(1500):toSeconds() == 1.5, "ms->s wrong")
check(time.duration.minutes(2):toSeconds() == 120, "minutes->s wrong")
check(time.duration.hours(1):toMinutes() == 60, "hours->m wrong")
check(time.duration.days(1):toHours() == 24, "days->h wrong")
check(time.duration.weeks(1):toDays() == 7, "weeks->d wrong")
check(time.duration.microseconds(1500):toNanoseconds() == 1500000, "us->ns wrong")
check(time.duration.create(1, 500000000):toSeconds() == 1.5, "create(s, subsec) wrong")
check(time.duration.milliseconds(1234):subsecmillis() == 234, "subsecmillis wrong")

-- Arithmetic and comparison operators
local d1 = time.duration.seconds(1)
local d2 = time.duration.milliseconds(500)
check((d1 + d2):toSeconds() == 1.5, "add wrong")
check((d1 - d2):toSeconds() == 0.5, "sub wrong")
check((d2 * 2):toSeconds() == 1, "mul wrong")
check((d1 / 4):toMilliseconds() == 250, "div wrong")
check(d2 < d1, "lt wrong")
check(d2 <= d2, "le wrong")
check(time.duration.seconds(1) == time.duration.milliseconds(1000), "eq wrong")

-- Values are frozen
check(not pcall(function()
	(time.duration.seconds(1) :: any).nanos = 0
end), "Duration should be frozen")

return true
