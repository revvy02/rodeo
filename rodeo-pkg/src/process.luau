-- Process / command execution available inside Studio scripts.
-- Bundled require: `local process = require("@rodeo/process")`.

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

export type Process = {
	args: { string },
	env: { [string]: string? },
	cwd: () -> string,
	homedir: () -> string,
	execpath: () -> string,
	exit: (code: number) -> (),
	run: (argsOrHandle: { string } | shared.ProcessHandle, options: shared.ProcessRunOptions?) -> shared.ProcessResult,
	system: (command: string, options: shared.ProcessRunOptions?) -> shared.ProcessResult,
	create: (args: { string }, options: shared.ProcessRunOptions?) -> shared.ProcessHandle,
	kill: (handle: shared.ProcessHandle) -> (),
}

return (singleton :: any).process :: Process
