-- Process / command execution available inside Studio scripts.
-- Bundled require: `local process = require("@rodeo/process")`.

local singleton = require("./_internal/singleton")
local shared = require("./types")

local process = {}

--- The command-line arguments passed to this rodeo execution after `--`.
process.args = (nil :: any) :: { string }

--- A read-only view of environment variables visible to this execution.
process.env = (nil :: any) :: { [string]: string? }

--- Returns the current working directory.
function process.cwd(): string
	return (singleton :: any).process.cwd()
end

--- Returns the user's home directory.
function process.homedir(): string
	return (singleton :: any).process.homedir()
end

--- Returns the path of the running rodeo binary.
function process.execpath(): string
	return (singleton :: any).process.execpath()
end

--- Exits the current execution with the given code.
function process.exit(code: number)
	(singleton :: any).process.exit(code)
end

--- Runs `args` (or an existing handle), blocking until completion. Returns
--- captured stdout/stderr and exit code.
function process.run(argsOrHandle: { string } | shared.ProcessHandle, options: shared.ProcessRunOptions?): shared.ProcessResult
	return (singleton :: any).process.run(argsOrHandle, options)
end

--- Like `run`, but takes a single shell-style command string.
function process.system(command: string, options: shared.ProcessRunOptions?): shared.ProcessResult
	return (singleton :: any).process.system(command, options)
end

--- Spawns `args` as a child process without waiting. Returns a handle with
--- stdin/stdout/stderr stream handles for live interaction.
function process.create(args: { string }, options: shared.ProcessRunOptions?): shared.ProcessHandle
	return (singleton :: any).process.create(args, options)
end

--- Terminates a process started with `create`.
function process.kill(handle: shared.ProcessHandle)
	(singleton :: any).process.kill(handle)
end

return process
