-- RodeoClient — top-level handle. Owns a Daemon subprocess and exposes
-- discovery + backend accessors. Mirrors rodeo-client-ts/src/client.ts.

local daemonMod = require("./daemon")
local studioMod = require("./studio")
local vmMod = require("./vm")

export type BackendInfo = { id: string, kind: string, name: string }
export type ProcessInfo = { [string]: any }

type StateSnapshot = {
	vms: { vmMod.VmSnapshot },
}

export type ConnectOpts = {
	host: string?,
	port: number,
	rodeoBin: string?,
}

export type RodeoClient = {
	isHealthy: () -> boolean,
	getState: () -> StateSnapshot,
	listProcesses: () -> { ProcessInfo },
	kill: (processId: number) -> (),
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

	function self.isHealthy()
		local ok, result = pcall(daemon.call, "client.isHealthy", {})
		if not ok then
			return false
		end
		return result == true
	end

	function self.getState()
		return daemon.call("client.getState", {})
	end

	function self.listProcesses()
		return daemon.call("client.listProcesses", {})
	end

	function self.kill(processId)
		daemon.call("client.kill", { processId = processId })
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
		for _, s in state.vms or {} do
			table.insert(out, vmMod.create(s, daemon))
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

	return self
end

return {
	connect = connect,
}
