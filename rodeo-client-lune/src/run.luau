-- Types for Vm.runCode — mirrors rodeo-client-ts/src/run.ts.

export type LogFilter = {
	enableWarn: boolean?,
	enableError: boolean?,
	enableInfo: boolean?,
	enableOutput: boolean?,
	enableLogs: boolean?,
}

export type RunCodeOpts = {
	source: string?,
	file: string?,
	sourcemap: string?,
	target: string?,
	showReturn: boolean?,
	cacheRequires: boolean?,
	verbose: boolean?,
	scriptArgs: { string }?,
	profile: string?,
	-- Write the script's return value to this host-side path. `.luau`/`.lua`
	-- emits Luau source (e.g. `return { pos = Vector3.new(1,2,3) }`); any
	-- other extension emits JSON-encoded tagged structs.
	returnFile: string?,
	processName: string?,
	logFilter: LogFilter?,
}

export type RunResult = {
	ok: boolean,
	output: string,
	exitCode: number,
	-- JSON-parsed script return value. `nil` if the script returned nothing
	-- or if the return payload failed to parse (the latter is swallowed
	-- defensively). Access via bracket notation because `return` is a Luau
	-- reserved keyword: `result["return"]`.
	["return"]: any?,
}

return {}
