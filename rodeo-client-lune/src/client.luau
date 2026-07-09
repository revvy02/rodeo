-- RodeoClient — top-level handle. Owns a Daemon subprocess and exposes
-- discovery + backend accessors. Mirrors rodeo-client-ts/src/client.ts.

local task = require("@lune/task")

local daemonMod = require("./daemon")
local studioMod = require("./studio")
local domMod = require("./dom")
local run = require("./run")
local exec = require("./exec")

export type BackendInfo = { id: string, kind: string, name: string }
export type ProcessInfo = { [string]: any }

type StudioDomEntry = {
	domId: string,
	domKind: string,
	userName: string?,
	userId: number?,
}

type StudioSnapshot = {
	studioId: string,
	backendId: string,
	-- Launch session identity; absent for manually-connected studios.
	sessionId: string?,
	placeName: string,
	placeId: number,
	status: string,
	studioMode: string,
	-- The root edit DOM's id; absent if no edit DOM is connected.
	editDomId: string?,
	doms: { StudioDomEntry },
}

type StateSnapshot = {
	backends: { any }?,
	processes: { any }?,
	studios: { StudioSnapshot },
}

export type ConnectOpts = {
	host: string?,
	port: number,
	rodeoBin: string?,
	-- Max time to wait for the server to come up. Default 30000ms.
	readyTimeoutMs: number?,
	-- Poll interval while waiting for the server. Default 200ms.
	readyPollMs: number?,
}

export type RodeoClient = {
	getState: () -> StateSnapshot,
	listProcesses: () -> { ProcessInfo },
	kill: (executionId: string) -> (),
	listBackends: (kind: string?) -> { BackendInfo },
	getLocalStudio: () -> studioMod.StudioBackend,
	getBackend: (idOrName: string) -> studioMod.StudioBackend,
	runCode: (opts: run.RunCodeOpts) -> run.RunResult,
	getDoms: () -> { domMod.Dom },
	getDom: (domId: string) -> domMod.Dom,
	close: () -> (),
}

local function connect(opts: ConnectOpts): RodeoClient
	local daemon = daemonMod.spawn({
		host = opts.host or "localhost",
		port = opts.port,
		rodeoBin = opts.rodeoBin,
	})

	local self = {} :: RodeoClient

	function self.getState()
		return daemon.call("client.getState", {})
	end

	function self.listProcesses()
		return daemon.call("client.listProcesses", {})
	end

	function self.kill(executionId)
		daemon.call("client.kill", { executionId = executionId })
	end

	function self.listBackends(kind)
		local params = if kind then { kind = kind } else {}
		return daemon.call("client.listBackends", params)
	end

	function self.getLocalStudio()
		local resp = daemon.call("client.getLocalStudio", {})
		return studioMod.createStudioBackend(resp.backendHandle, resp.info, daemon)
	end

	function self.getBackend(idOrName)
		local resp = daemon.call("client.getBackend", { idOrName = idOrName })
		return studioMod.createStudioBackend(resp.backendHandle, resp.info, daemon)
	end

	-- Serve-wide run tier: master routes by mode/domKind/context across all
	-- connected DOMs.
	function self.runCode(opts)
		return exec.runViaDaemon(daemon, "client.runCode", {}, opts)
	end

	function self.getDoms()
		local state = self.getState()
		local out = {}
		for _, studio in state.studios or {} do
			for _, sv in studio.doms or {} do
				local snap: domMod.DomSnapshot = {
					domId = sv.domId,
					domKind = sv.domKind,
					mode = if sv.domKind == "edit" then "edit" else studio.studioMode,
					backendId = studio.backendId,
					sessionGuid = studio.sessionId,
					placeId = studio.placeId,
					gameName = studio.placeName,
					connected = true,
					activeRuns = 0,
					userName = sv.userName,
					userId = sv.userId,
				}
				table.insert(out, domMod.create(snap, daemon))
			end
		end
		return out
	end

	function self.getDom(domId)
		for _, v in self.getDoms() do
			if v.domId == domId then
				return v
			end
		end
		error(`dom '{domId}' not found`)
	end

	function self.close()
		daemon.shutdown()
	end

	-- Block until the server is reachable, or throw on timeout.
	local timeoutMs = opts.readyTimeoutMs or 30000
	local pollMs = opts.readyPollMs or 200
	local deadline = os.clock() + timeoutMs / 1000
	while os.clock() < deadline do
		local ok, result = pcall(daemon.call, "client.isHealthy", {})
		if ok and result == true then
			return self
		end
		task.wait(pollMs / 1000)
	end
	pcall(daemon.shutdown)
	error(`rodeo.connect: timed out after {timeoutMs}ms waiting for rodeo at {opts.host or "localhost"}:{opts.port}`)
end

return {
	connect = connect,
}
