-- NDJSON JSON-RPC 2.0 broker over a `rodeo __spawn_canonical_client` subprocess.
-- Mirrors rodeo-client-ts/src/daemon.ts. One daemon per RodeoClient.

local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

export type StreamCallback = (method: string, params: { [string]: any }) -> ()

export type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: StreamCallback) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}

local function spawn(opts: { host: string, port: number, rodeoBin: string? }): Daemon
	local bin = opts.rodeoBin or "rodeo"
	local child = process.create(bin, {
		"__spawn_canonical_client",
		"--host", opts.host,
		"--port", tostring(opts.port),
	})

	local nextId = 0
	local pending: { [number]: (msg: any) -> () } = {}
	local streams: { [string]: StreamCallback } = {}
	local shuttingDown = false

	local self: Daemon
	self = {} :: any

	local function drainPending(errorMessage: string)
		local toDrain = pending
		pending = {}
		for _, cb in toDrain do
			cb({ error = { code = -1, message = errorMessage } })
		end
	end

	-- Stderr drain: lune pipes stderr unconditionally; if we don't consume it
	-- the kernel buffer fills (~64KB on macOS) and the daemon blocks on its
	-- next stderr write, which stalls stdout too. Forward to our own stderr
	-- so tracing output still appears.
	task.spawn(function()
		while true do
			local chunk: string? = child.stderr:read()
			if chunk == nil then
				break
			end
			pcall(stdio.ewrite, chunk)
		end
	end)

	-- Reader coroutine: read stdout chunks, split on LF, dispatch each line.
	task.spawn(function()
		local buf = ""
		while true do
			local chunk: string? = child.stdout:read()
			if chunk == nil then
				break
			end
			buf = buf .. chunk
			while true do
				local nl = string.find(buf, "\n", 1, true)
				if nl == nil then
					break
				end
				local line = string.sub(buf, 1, nl - 1)
				buf = string.sub(buf, nl + 1)
				if line ~= "" then
					local ok, msg = pcall(serde.decode, "json", line)
					if ok and type(msg) == "table" then
						-- Responses have `id` and no `method`; notifications have
						-- `method` and no `id`. Distinguishing by presence of
						-- `result`/`error` fails because JSON null decodes to nil,
						-- so a valid `{"id":N,"result":null}` looks like an empty
						-- object to the Luau side.
						if msg.id ~= nil and msg.method == nil then
							local cb = pending[msg.id]
							if cb then
								pending[msg.id] = nil
								cb(msg)
							end
						elseif type(msg.method) == "string" then
							local streamId = msg.params and msg.params.streamId
							local scb = type(streamId) == "string" and streams[streamId] or nil
							if scb then
								scb(msg.method, msg.params)
							end
						end
					end
				end
			end
		end
		drainPending("daemon stdout closed")
	end)

	function self.call(method, params)
		nextId += 1
		local id = nextId
		local co = coroutine.running()
		assert(co, "daemon.call must be invoked from a coroutine")

		pending[id] = function(msg)
			if msg.error ~= nil then
				task.spawn(co, false, msg.error)
			else
				task.spawn(co, true, msg.result)
			end
		end

		local encoded = serde.encode("json", {
			jsonrpc = "2.0",
			id = id,
			method = method,
			params = params or {},
		})
		child.stdin:write(encoded .. "\n")

		local ok, resultOrErr = coroutine.yield()
		if not ok then
			local err = resultOrErr :: { message: string? }
			error(`rpc {method}: {err.message or "unknown error"}`, 2)
		end
		return resultOrErr
	end

	function self.registerStream(streamId, cb)
		streams[streamId] = cb
	end

	function self.unregisterStream(streamId)
		streams[streamId] = nil
	end

	function self.shutdown()
		if shuttingDown then
			return
		end
		shuttingDown = true
		-- Close stdin → daemon exits naturally; force-kill as fallback.
		pcall(function()
			child.stdin:close()
		end)
		pcall(function()
			child:kill()
		end)
	end

	return self
end

return { spawn = spawn }
