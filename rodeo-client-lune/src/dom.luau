-- Dom handle. Carries per-DOM metadata + exposes runCode against the daemon.
-- Mirrors rodeo-client-ts/src/client.ts `class Dom`.

local run = require("./run")
local exec = require("./exec")

type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: (string, { [string]: any }) -> ()) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

export type DomSnapshot = {
	domId: string,
	backendId: string?,
	mode: string?,
	domKind: string?,
	sessionGuid: string?,
	placeId: number?,
	gameName: string?,
	connected: boolean,
	activeRuns: number,
	userName: string?,
	userId: number?,
}

export type Dom = {
	domId: string,
	backendId: string,
	mode: string,
	domKind: string,
	sessionGuid: string?,
	placeId: number,
	gameName: string,
	connected: boolean,
	activeRuns: number,
	runCode: (opts: run.DomRunCodeOpts) -> run.RunResult,
}

local function create(snap: DomSnapshot, daemon: Daemon): Dom
	local self = {} :: Dom
	self.domId = snap.domId
	self.backendId = snap.backendId or ""
	self.mode = snap.mode or ""
	self.domKind = snap.domKind or ""
	self.sessionGuid = snap.sessionGuid
	self.placeId = snap.placeId or 0
	self.gameName = snap.gameName or ""
	self.connected = snap.connected
	self.activeRuns = snap.activeRuns

	-- Run on THIS DOM (pinned — no routing). Only `context` applies.
	function self.runCode(opts)
		return exec.runViaDaemon(daemon, "dom.runCode", { domId = self.domId }, opts)
	end

	return self
end

return {
	create = create,
}
