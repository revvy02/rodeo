-- Transport-agnostic typed RPC module for rodeo.
-- Caller provides a `send` function that forwards the message to the transport
-- (BindableEvent in the plugin).
--
-- Data discipline: we produce the canonical ClientRpcCall JSON shape at `call`
-- time, minus `executionId` which the transport layer stamps in (it's the only
-- field rpc.luau doesn't know). Everything downstream consumes this canonical
-- shape without per-method knowledge — the proto library's jsonDecode handles
-- the oneof dispatch.
--
-- API:
--   rpc.call(reqType, reqValue) -> resValue    -- blocking, errors on failure
--   rpc.notify(reqType, reqValue)              -- fire-and-forget
--   rpc.handleResponse(message)                -- transport layer delivers responses here
--
-- reqType: string tag matching a ClientRpcCall.req oneof case (e.g. "stream_read_chunk")
-- reqValue: a constructed proto message (e.g. StreamReadChunkRequest.new({...}))
-- resValue: the typed response's value (metatable stripped during cross-context delivery;
--           field access works fine since values live on the table itself)

local function snakeToCamel(s: string): string
	return (s:gsub("_(%w)", function(c)
		return c:upper()
	end))
end

return function(send: (message: any) -> ())
	local pendingRpcs: { [string]: BindableEvent } = {}
	local idCounter = 0

	-- Build the canonical ClientRpcCall JSON shape with the oneof case set.
	-- `executionId` is added by the transport (MessageHandler in the plugin).
	-- reqValue may be typed (plugin runner) or an already-encoded plain table.
	local function buildCallJson(id: string, reqType: string, reqValue: any): { [string]: any }
		local encoded = if type(reqValue) == "table" and type(reqValue.jsonEncode) == "function"
			then reqValue:jsonEncode()
			else reqValue
		return {
			id = id,
			[snakeToCamel(reqType)] = encoded,
		}
	end

	local function call(reqType: string, reqValue: any): any
		idCounter += 1
		local id = tostring(idCounter)

		local event = Instance.new("BindableEvent")
		pendingRpcs[id] = event

		send({ type = "rpc", callJson = buildCallJson(id, reqType, reqValue) })

		local response = event.Event:Wait()
		event:Destroy()

		-- response: { type = <resType>, value = <resValue> } | { type = "error", value = <string> }
		if response.type == "error" then
			error("RPC error [" .. reqType .. "]: " .. tostring(response.value))
		end
		return response.value
	end

	local function notify(reqType: string, reqValue: any)
		send({ type = "rpc", callJson = buildCallJson("", reqType, reqValue) })
	end

	-- Called by the transport layer when a typed ClientRpcResponse arrives.
	-- `message` is { id, res } where res is the tagged oneof variant.
	local function handleResponse(message: any)
		local id = message.id
		if id and pendingRpcs[id] then
			local event = pendingRpcs[id]
			pendingRpcs[id] = nil
			event:Fire(message.res)
		end
	end

	return {
		call = call,
		notify = notify,
		handleResponse = handleResponse,
	}
end
