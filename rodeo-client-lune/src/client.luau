-- RodeoClient — top-level handle. Owns a Daemon subprocess and exposes
-- discovery + backend accessors. Mirrors rodeo-client-ts/src/client.ts.

local task = require("@lune/task")

local daemonMod = require("./daemon")
local studioMod = require("./studio")
local vmMod = require("./vm")

export type BackendInfo = { id: string, kind: string, name: string }
export type ProcessInfo = { [string]: any }

type StudioVmEntry = {
	vmId: string,
	dom: string,
	clientName: string?,
}

type StudioSnapshot = {
	id: string,
	backendId: string,
	mcpStudioId: string?,
	name: string,
	placeId: number,
	active: boolean,
	status: string,
	mode: string,
	vms: { StudioVmEntry },
}

type StateSnapshot = {
	backends: { any }?,
	processes: { any }?,
	-- DEPRECATED: prefer `studios[].vms`. Still present for now.
	vms: { vmMod.VmSnapshot }?,
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
	getStudio: (idOrName: string) -> studioMod.StudioBackend,
	getVms: () -> { vmMod.Vm },
	getVm: (vmId: string) -> vmMod.Vm,
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

	function self.getStudio(idOrName)
		local resp = daemon.call("client.getStudio", { idOrName = idOrName })
		return studioMod.createStudioBackend(resp.backendHandle, resp.info, daemon)
	end

	function self.getVms()
		local state = self.getState()
		local out = {}
		for _, studio in state.studios or {} do
			for _, sv in studio.vms or {} do
				local snap: vmMod.VmSnapshot = {
					vmId = sv.vmId,
					dom = sv.dom,
					mode = if sv.dom == "edit" then "edit" else studio.mode,
					backendId = studio.backendId,
					sessionGuid = studio.id,
					placeId = studio.placeId,
					gameName = studio.name,
					connected = true,
					activeRuns = 0,
					clientName = sv.clientName,
				}
				table.insert(out, vmMod.create(snap, daemon))
			end
		end
		return out
	end

	function self.getVm(vmId)
		for _, v in self.getVms() do
			if v.vmId == vmId then
				return v
			end
		end
		error(`vm '{vmId}' not found`)
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
