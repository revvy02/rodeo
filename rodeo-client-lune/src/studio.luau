-- StudioBackend + Studio + MultiplayerTest.
-- Mirrors the TS client's class hierarchy; dot-notation method surface.

local vmMod = require("./vm")

type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: (string, { [string]: any }) -> ()) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

type BackendInfo = { id: string, name: string }

-- Build a full VmSnapshot-shaped table from a parent studio + one of its
-- minimal (vmId/dom/clientName) vm entries.
local function vmSnapshotFromStudio(studio: any, sv: any): vmMod.VmSnapshot
	return {
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
end

-- Find a vmId across state.studios[].vms and return the built VmSnapshot table,
-- or nil if not present.
local function vmFromStudios(state: any, vmId: string): vmMod.VmSnapshot?
	for _, studio in state.studios or {} do
		for _, sv in studio.vms or {} do
			if sv.vmId == vmId then
				return vmSnapshotFromStudio(studio, sv)
			end
		end
	end
	return nil
end

local function vmListFromState(daemon: Daemon): { vmMod.Vm }
	local state = daemon.call("client.getState", {})
	local vms = {}
	for _, studio in state.studios or {} do
		for _, sv in studio.vms or {} do
			table.insert(vms, vmMod.create(vmSnapshotFromStudio(studio, sv), daemon))
		end
	end
	return vms
end

-- ---------------------------------------------------------------------------
-- Studio
-- ---------------------------------------------------------------------------

export type SaveResult = {
	saved: boolean,
	path: string?,
	error: string?,
}

-- ---------------------------------------------------------------------------
-- MultiplayerTest — an in-Studio multiplayer test session (server + N clients).
-- The server/client VMs are ordinary Vms (run via vm.runCode); the session
-- lifecycle (addPlayers/leave/end) is layered on top.
-- ---------------------------------------------------------------------------

export type MultiplayerTest = {
	server: vmMod.Vm,
	clients: { vmMod.Vm },
	addPlayers: (numPlayers: number) -> (),
	leave: (index: number) -> (),
	["end"]: () -> (),
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
	startMultiplayerTest: (numPlayers: number) -> MultiplayerTest,
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

	function self.startMultiplayerTest(numPlayers)
		local resp = daemon.call("studio.startMultiplayerTest", {
			studioHandle = handle,
			numPlayers = numPlayers,
		})
		local mpHandle = resp.mpHandle

		local function buildVm(vmId: string): vmMod.Vm
			local state = daemon.call("client.getState", {})
			local snap = vmFromStudios(state, vmId)
			if not snap then
				error(`multiplayer VM {vmId} not found`)
			end
			return vmMod.create(snap, daemon)
		end

		local function buildClients(vmIds: { string }): { vmMod.Vm }
			local clients = {}
			for _, vmId in vmIds do
				table.insert(clients, buildVm(vmId))
			end
			return clients
		end

		local mp = {} :: MultiplayerTest
		mp.server = buildVm(resp.serverVmId)
		mp.clients = buildClients(resp.clientVmIds or {})

		function mp.addPlayers(n)
			local r = daemon.call("mp.addPlayers", { mpHandle = mpHandle, numPlayers = n })
			mp.clients = buildClients(r.clientVmIds or {})
		end

		function mp.leave(index)
			daemon.call("mp.leave", { mpHandle = mpHandle, index = index })
		end

		mp["end"] = function()
			daemon.call("mp.end", { mpHandle = mpHandle })
		end

		return mp
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
	noHud: boolean?,
}

export type OpenPlaceOpts = {
	placeId: number,
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	noHud: boolean?,
}

export type OpenFileOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	noHud: boolean?,
}

export type StudioBackend = {
	id: string,
	name: string,
	open: (opts: OpenOpts?) -> Studio,
	openPlace: (opts: OpenPlaceOpts) -> Studio,
	openFile: (path: string, opts: OpenFileOpts?) -> Studio,
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
			noHud = opts.noHud == true,
			detached = opts.detached == true,
		})
	end

	return self
end

return {
	createStudioBackend = createStudioBackend,
}
