-- StudioBackend + Studio + MultiplayerTestServer/MultiplayerTestClient.
-- Mirrors the TS client's class hierarchy; dot-notation method surface.

local domMod = require("./dom")
local run = require("./run")
local exec = require("./exec")

type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: (string, { [string]: any }) -> ()) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

type BackendInfo = { id: string, name: string }

-- Build a full DomSnapshot-shaped table from a parent studio + one of its
-- minimal (domId/domKind/userName/userId) dom entries.
local function domSnapshotFromStudio(studio: any, sv: any): domMod.DomSnapshot
	return {
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
end

-- Find a domId across state.studios[].doms and return the built DomSnapshot table,
-- or nil if not present.
local function domFromStudios(state: any, domId: string): domMod.DomSnapshot?
	for _, studio in state.studios or {} do
		for _, sv in studio.doms or {} do
			if sv.domId == domId then
				return domSnapshotFromStudio(studio, sv)
			end
		end
	end
	return nil
end

local function domListFromState(daemon: Daemon): { domMod.Dom }
	local state = daemon.call("client.getState", {})
	local doms = {}
	for _, studio in state.studios or {} do
		for _, sv in studio.doms or {} do
			table.insert(doms, domMod.create(domSnapshotFromStudio(studio, sv), daemon))
		end
	end
	return doms
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
-- MultiplayerTestServer / MultiplayerTestClient — Dom-with-extras. Same data
-- plane (runCode, domId, ...) as any Dom, plus the test lifecycle keyed by the
-- daemon-side mpHandle.
-- ---------------------------------------------------------------------------

export type MultiplayerTestClient = domMod.Dom & {
	disconnect: () -> (),
}

export type MultiplayerTestServer = domMod.Dom & {
	connectClient: () -> MultiplayerTestClient,
	close: () -> (),
}

export type Studio = {
	sessionGuid: string,
	backendId: string,
	editDom: domMod.Dom,
	serverDom: domMod.Dom?,
	clientDom: domMod.Dom?,
	setMode: (mode: string) -> (),
	getMode: () -> string,
	save: () -> SaveResult,
	close: () -> (),
	getDoms: () -> { domMod.Dom },
	runCode: (opts: run.RunCodeOpts) -> run.RunResult,
	startMultiplayerTest: () -> MultiplayerTestServer,
}

local function createStudio(
	handle: string,
	sessionGuid: string,
	backendId: string,
	editDom: domMod.Dom,
	daemon: Daemon
): Studio
	local self = {} :: Studio
	self.sessionGuid = sessionGuid
	self.backendId = backendId
	self.editDom = editDom
	self.serverDom = nil
	self.clientDom = nil

	function self.getDoms()
		local list = daemon.call("studio.getDoms", { studioHandle = handle })
		local out = {}
		for _, s in list do
			table.insert(out, domMod.create(s, daemon))
		end
		return out
	end

	-- Session-scoped run tier: routes by mode/domKind/context among THIS
	-- studio's DOMs (auto-transitioning its mode).
	function self.runCode(opts)
		return exec.runViaDaemon(daemon, "studio.runCode", { studioHandle = handle }, opts)
	end

	function self.setMode(mode)
		local resp = daemon.call("studio.setMode", { studioHandle = handle, mode = mode })
		if mode == "edit" then
			self.serverDom = nil
			self.clientDom = nil
			return
		end
		local all = domListFromState(daemon)
		local function find(id: string?): domMod.Dom?
			if not id then
				return nil
			end
			for _, v in all do
				if v.domId == id then
					return v
				end
			end
			return nil
		end
		self.serverDom = find(resp.serverDomId)
		self.clientDom = if mode == "test" or mode == "play" then find(resp.clientDomId) else nil
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

	function self.startMultiplayerTest()
		local resp = daemon.call("studio.startMultiplayerTest", {
			studioHandle = handle,
		})
		local mpHandle = resp.mpHandle

		local function buildVm(domId: string): domMod.Dom
			local state = daemon.call("client.getState", {})
			local snap = domFromStudios(state, domId)
			if not snap then
				error(`multiplayer DOM {domId} not found`)
			end
			return domMod.create(snap, daemon)
		end

		local server = buildVm(resp.serverDomId) :: any

		function server.connectClient(): MultiplayerTestClient
			local r = daemon.call("mp.connectClient", { mpHandle = mpHandle })
			local client = buildVm(r.clientDomId) :: any

			function client.disconnect()
				daemon.call("mp.disconnectClient", { mpHandle = mpHandle, domId = client.domId })
			end

			return client :: MultiplayerTestClient
		end

		function server.close()
			daemon.call("mp.close", { mpHandle = mpHandle })
		end

		return server :: MultiplayerTestServer
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
	showWidgets: string?,
}

export type OpenPlaceOpts = {
	placeId: number,
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	showWidgets: string?,
}

export type OpenFileOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	showWidgets: string?,
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
		-- Find the editDom among this studio's DOMs.
		local editDom: domMod.Dom? = nil
		local studioDoms = daemon.call("studio.getDoms", { studioHandle = resp.studioHandle })
		for _, s in studioDoms do
			if s.domId == resp.editDomId then
				editDom = domMod.create(s, daemon)
				break
			end
		end
		if not editDom then
			error(`edit DOM {resp.editDomId} not found in studio {resp.studioHandle}`)
		end
		return createStudio(resp.studioHandle, resp.sessionGuid, info.id, editDom :: domMod.Dom, daemon)
	end

	function self.open(opts)
		opts = opts or {}
		return launch("studio.open", {
			backendHandle = handle,
			fflags = opts.fflags or {},
			background = opts.background == true,
			profile = opts.profile == true,
			showWidgets = opts.showWidgets,
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
			showWidgets = opts.showWidgets,
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
			showWidgets = opts.showWidgets,
			detached = opts.detached == true,
		})
	end

	return self
end

return {
	createStudioBackend = createStudioBackend,
}
