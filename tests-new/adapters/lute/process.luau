-- @lute/process conformance, per submodules/lute/definitions/process.luau.
local process = require("@lute/process")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

check(type(process.args) == "table", "args should be a table")
check(type(process.env) == "table", "env should be a table")
check(#process.cwd() > 0, "cwd empty")
check(#process.homedir() > 0, "homedir empty")
check(#process.execPath() > 0, "execPath empty")

-- run: ProcessResult shape (stdout/stderr/ok/exitcode)
local echoed = process.run({ "echo", "lute-run" })
check(echoed.ok == true, "run.ok wrong")
check(echoed.exitcode == 0, "run.exitcode wrong")
check(echoed.stdout == "lute-run\n", `run.stdout wrong: '{echoed.stdout}'`)
check(echoed.stderr == "", "run.stderr should be empty")

-- failing command reports ok = false and the code
local failed = process.run({ "sh", "-c", "exit 3" })
check(failed.ok == false, "failed run.ok wrong")
check(failed.exitcode == 3, `failed run.exitcode wrong: {failed.exitcode}`)

-- system: through the shell
local sys = process.system("echo lute-system")
check(sys.ok and sys.stdout == "lute-system\n", "system output wrong")

-- unsupported surface errors clearly
check(not pcall(process.pid), "pid should error under rodeo")
check(not pcall(process.onSignal, "SIGINT", function() end), "onSignal should error under rodeo")

return true
