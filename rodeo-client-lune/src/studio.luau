-- StudioBackend + Studio + MultiplayerTestServer/Client.
-- Mirrors the TS client's class hierarchy; dot-notation method surface.

local vmMod = require("./vm")

type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: (string, { [string]: any }) -> ()) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

type BackendInfo = { id: string, name: string }

local function vmListFromState(daemon: Daemon): { vmMod.Vm }
	local state = daemon.call("client.getState", {})
	local vms = {}
	for _, s in state.vms or {} do
		table.insert(vms, vmMod.create(s, daemon))
	end
	return vms
end

-- ---------------------------------------------------------------------------
-- MultiplayerTestClient — a Vm with .disconnect() (lifecycle) glued on.
-- The data plane (runCode etc) is the underlying Vm; only the session
-- lifecycle is bonus.
-- ---------------------------------------------------------------------------

export type MultiplayerTestClient = vmMod.Vm & {
	disconnect: () -> (),
}

local function decorateMultiplayerTestClient(vm: vmMod.Vm, daemon: Daemon): MultiplayerTestClient
	local self = vm :: any
	function self.disconnect()
		daemon.call("vm.disconnectClient", { vmId = vm.vmId })
	end
	return self :: MultiplayerTestClient
end

-- ---------------------------------------------------------------------------
-- MultiplayerTestServer — a Vm with .close() / .connectClient() glued on.
-- ---------------------------------------------------------------------------

export type MultiplayerTestServer = vmMod.Vm & {
	connectClient: () -> MultiplayerTestClient,
	close: () -> (),
}

local function decorateMultiplayerTestServer(vm: vmMod.Vm, daemon: Daemon): MultiplayerTestServer
	local self = vm :: any

	function self.connectClient()
		local resp = daemon.call("vm.connectClient", { vmId = vm.vmId })
		local state = daemon.call("client.getState", {})
		local clientVm: vmMod.Vm? = nil
		for _, s in state.vms or {} do
			if s.vmId == resp.vmId then
				clientVm = vmMod.create(s, daemon)
				break
			end
		end
		if not clientVm then
			error(`client VM {resp.vmId} not found`)
		end
		return decorateMultiplayerTestClient(clientVm :: vmMod.Vm, daemon)
	end

	function self.close()
		daemon.call("vm.closeServer", { vmId = vm.vmId })
	end

	return self :: MultiplayerTestServer
end

-- ---------------------------------------------------------------------------
-- Studio
-- ---------------------------------------------------------------------------

export type StartMultiplayerTestOpts = {
	placeFile: string?,
	placeId: number?,
	fflags: { string }?,
	profile: boolean?,
	runId: string?,
	noHud: boolean?,
}

export type SaveResult = {
	saved: boolean,
	path: string?,
	error: string?,
}

export type Studio = {
	sessionGuid: string,
	backendId: string,
	editVm: vmMod.Vm,
	serverVm: vmMod.Vm?,
	clientVm: vmMod.Vm?,
	setMode: (mode: string) -> (),
	getMode: () -> string,
	save: () -> SaveResult,
	close: () -> (),
	getVms: () -> { vmMod.Vm },
}

local function createStudio(
	handle: string,
	sessionGuid: string,
	backendId: string,
	editVm: vmMod.Vm,
	daemon: Daemon
): Studio
	local self = {} :: Studio
	self.sessionGuid = sessionGuid
	self.backendId = backendId
	self.editVm = editVm
	self.serverVm = nil
	self.clientVm = nil

	function self.getVms()
		local list = daemon.call("studio.getVms", { studioHandle = handle })
		local out = {}
		for _, s in list do
			table.insert(out, vmMod.create(s, daemon))
		end
		return out
	end

	function self.setMode(mode)
		local resp = daemon.call("studio.setMode", { studioHandle = handle, mode = mode })
		if mode == "edit" then
			self.serverVm = nil
			self.clientVm = nil
			return
		end
		local all = vmListFromState(daemon)
		local function find(id: string?): vmMod.Vm?
			if not id then
				return nil
			end
			for _, v in all do
				if v.vmId == id then
					return v
				end
			end
			return nil
		end
		self.serverVm = find(resp.serverVmId)
		self.clientVm = if mode == "test" or mode == "play" then find(resp.clientVmId) else nil
	end

	function self.getMode()
		return daemon.call("studio.getMode", { studioHandle = handle })
	end

	function self.save()
		return daemon.call("studio.save", { studioHandle = handle })
	end

	function self.close()
		daemon.call("studio.close", { studioHandle = handle })
	end

	return self
end

-- ---------------------------------------------------------------------------
-- StudioBackend
-- ---------------------------------------------------------------------------

export type OpenOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}

export type OpenPlaceOpts = {
	placeId: number,
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}

export type OpenFileOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}

export type StudioBackend = {
	id: string,
	name: string,
	open: (opts: OpenOpts?) -> Studio,
	openPlace: (opts: OpenPlaceOpts) -> Studio,
	openFile: (path: string, opts: OpenFileOpts?) -> Studio,
	startMultiplayerTest: (opts: StartMultiplayerTestOpts?) -> MultiplayerTestServer,
}

local function createStudioBackend(handle: string, info: BackendInfo, daemon: Daemon): StudioBackend
	local self = {} :: StudioBackend
	self.id = info.id
	self.name = info.name

	local function launch(method: string, params: { [string]: any }): Studio
		local resp = daemon.call(method, params)
		-- Find the editVm among this studio's VMs.
		local editVm: vmMod.Vm? = nil
		local studioVms = daemon.call("studio.getVms", { studioHandle = resp.studioHandle })
		for _, s in studioVms do
			if s.vmId == resp.editVmId then
				editVm = vmMod.create(s, daemon)
				break
			end
		end
		if not editVm then
			error(`edit VM {resp.editVmId} not found in studio {resp.studioHandle}`)
		end
		return createStudio(resp.studioHandle, resp.sessionGuid, info.id, editVm :: vmMod.Vm, daemon)
	end

	function self.open(opts)
		opts = opts or {}
		return launch("studio.open", {
			backendHandle = handle,
			fflags = opts.fflags or {},
			background = opts.background == true,
			profile = opts.profile == true,
			logs = opts.logs,
			noHud = opts.noHud == true,
			detached = opts.detached == true,
		})
	end

	function self.openPlace(opts)
		return launch("studio.openPlace", {
			backendHandle = handle,
			placeId = opts.placeId,
			fflags = opts.fflags or {},
			background = opts.background == true,
			profile = opts.profile == true,
			logs = opts.logs,
			noHud = opts.noHud == true,
			detached = opts.detached == true,
		})
	end

	function self.openFile(path, opts)
		opts = opts or {}
		return launch("studio.openFile", {
			backendHandle = handle,
			path = path,
			fflags = opts.fflags or {},
			background = opts.background == true,
			profile = opts.profile == true,
			logs = opts.logs,
			noHud = opts.noHud == true,
			detached = opts.detached == true,
		})
	end

	function self.startMultiplayerTest(opts)
		opts = opts or {}
		local resp = daemon.call("backend.startMultiplayerTest", {
			backendHandle = handle,
			placeFile = opts.placeFile,
			placeId = opts.placeId,
			fflags = opts.fflags or {},
			profile = opts.profile == true,
			runId = opts.runId,
			noHud = opts.noHud == true,
		})
		local all = vmListFromState(daemon)
		local serverVm: vmMod.Vm? = nil
		for _, v in all do
			if v.vmId == resp.vmId then
				serverVm = v
				break
			end
		end
		if not serverVm then
			error(`server VM {resp.vmId} not found`)
		end
		return decorateMultiplayerTestServer(serverVm :: vmMod.Vm, daemon)
	end

	return self
end

return {
	createStudioBackend = createStudioBackend,
}
