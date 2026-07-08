-- Vm handle. Carries per-VM metadata + exposes runCode against the daemon.
-- Mirrors rodeo-client-ts/src/client.ts `class Vm`.

local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local run = require("./run")
local uuid = require("./util/uuid")

type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: (string, { [string]: any }) -> ()) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

export type VmSnapshot = {
	vmId: string,
	backendId: string?,
	mode: string?,
	dom: string?,
	sessionGuid: string?,
	placeId: number?,
	gameName: string?,
	connected: boolean,
	activeRuns: number,
	clientName: string?,
}

export type Vm = {
	vmId: string,
	backendId: string,
	mode: string,
	dom: string,
	sessionGuid: string?,
	placeId: number,
	gameName: string,
	connected: boolean,
	activeRuns: number,
	runCode: (opts: run.RunCodeOpts) -> run.RunResult,
}

type ProcessedSource = {
	script: string,
	scriptPath: string?,
	instancePath: string?,
}

local function processSource(opts: run.RunCodeOpts): ProcessedSource
	local args = { "__process_source" }
	if opts.file then
		table.insert(args, opts.file)
		if opts.sourcemap then
			table.insert(args, "--sourcemap")
			table.insert(args, opts.sourcemap)
		end
	elseif opts.source then
		table.insert(args, "--source")
		table.insert(args, opts.source)
	else
		error("runCode requires either `source` or `file`")
	end
	local result = process.exec("rodeo", args)
	if not result.ok then
		error(`source processing failed: {result.stderr}`)
	end
	return serde.decode("json", result.stdout) :: ProcessedSource
end

local function create(snap: VmSnapshot, daemon: Daemon): Vm
	local self = {} :: Vm
	self.vmId = snap.vmId
	self.backendId = snap.backendId or ""
	self.mode = snap.mode or ""
	self.dom = snap.dom or ""
	self.sessionGuid = snap.sessionGuid
	self.placeId = snap.placeId or 0
	self.gameName = snap.gameName or ""
	self.connected = snap.connected
	self.activeRuns = snap.activeRuns

	function self.runCode(opts)
		local processed = processSource(opts)

		-- Local tag for the default profile-dir name only — NOT the run id
		-- (the master mints that; it comes back on the result as executionId).
		local profileTag = uuid.v4()
		-- profile is a directory path sent straight to the daemon. The daemon
		-- passes it to rodeo-client, which writes files directly to disk — this
		-- process never sees the bytes.
		local profileDir: string? = nil
		if opts.profile ~= nil then
			profileDir = if opts.profile ~= "" then opts.profile else `.rodeo/.temp/profiles/{profileTag}`
		end

		local streamId = uuid.v4()
		local bufferedOutput = {}

		local co = coroutine.running()
		assert(co, "runCode must run in a coroutine")

		local done = false
		local finalResult: run.RunResult? = nil
		local finalError: string? = nil

		daemon.registerStream(streamId, function(method, params)
			if done then
				return
			end
			if method == "stream.data" then
				local kind = params.kind
				if kind == "stdout" or kind == "stderr" then
					table.insert(bufferedOutput, tostring(params.chunk or ""))
				end
			elseif method == "stream.done" then
				daemon.unregisterStream(streamId)
				done = true
				local r = params.result or {}
				local output = (type(r.output) == "string" and #r.output > 0) and r.output or table.concat(bufferedOutput)
				-- Daemon ships return value as a JSON string. Parse here so
				-- consumers can write `result["return"]` directly. Parse
				-- failures are swallowed — never throw at the consumer.
				local parsedReturn: any = nil
				if type(r.returnValue) == "string" and #r.returnValue > 0 then
					local ok, decoded = pcall(serde.decode, "json", r.returnValue)
					if ok then
						parsedReturn = decoded
					end
				end
				finalResult = {
					ok = r.ok == true,
					output = output,
					exitCode = r.exitCode or 0,
					executionId = if type(r.executionId) == "string" then r.executionId else nil,
					["return"] = parsedReturn,
				}
				task.spawn(co)
			elseif method == "stream.error" then
				daemon.unregisterStream(streamId)
				done = true
				finalError = tostring(params.error or "run failed")
				task.spawn(co)
			end
		end)

		local callOk, callErr = pcall(daemon.call, "vm.runCode", {
			vmId = self.vmId,
			streamId = streamId,
			source = processed.script,
			target = opts.target,
			showReturn = opts.showReturn == true,
			cacheRequires = opts.cacheRequires == true,
			verbose = opts.verbose == true,
			scriptArgs = opts.scriptArgs or {},
			profileDir = profileDir,
			returnFile = opts.returnFile,
			instancePath = processed.instancePath,
			scriptPath = processed.scriptPath,
			logFilter = opts.logFilter,
		})
		if not callOk then
			daemon.unregisterStream(streamId)
			error(callErr, 2)
		end

		if not done then
			coroutine.yield()
		end

		if finalError then
			error(finalError, 2)
		end
		return assert(finalResult, "runCode completed with no result")
	end

	return self
end

return {
	create = create,
}
