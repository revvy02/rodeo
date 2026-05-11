-- @rodeo/stream API over typed RPC.
-- Public surface: read, write, close. The split (readChunk/readLine/readAll) lives at
-- the RPC layer only — `read` dispatches based on handle kind.
local runtime = _G.__rodeo_runtime_proto

return function(rpc)
	local stream = {}

	local function readChunk(handle, size: number?): runtime.StreamReadChunkResponse
		return rpc.call("stream_read_chunk", runtime.StreamReadChunkRequest.new({
			handle = handle.__handle,
			size = size,
		}))
	end

	local function readLine(handle): runtime.StreamReadLineResponse
		return rpc.call("stream_read_line", runtime.StreamReadLineRequest.new({
			handle = handle.__handle,
		}))
	end

	local function readAll(handle): runtime.StreamReadAllResponse
		return rpc.call("stream_read_all", runtime.StreamReadAllRequest.new({
			handle = handle.__handle,
		}))
	end

	-- Public read: dispatches based on handle prefix convention.
	--   "stdin"                → readLine
	--   "file:..."             → readAll
	--   "proc:<pid>:stdout"    → readChunk
	--   "proc:<pid>:stderr"    → readChunk
	function stream.read(handle): string?
		local h = handle.__handle
		if h == "stdin" then
			local ok, r = pcall(readLine, handle)
			if not ok then return nil end
			return r.data
		elseif h:sub(1, 5) == "file:" then
			local ok, r = pcall(readAll, handle)
			if not ok then return nil end
			return r.data
		elseif h:match("^proc:.+:std%w+$") then
			local ok, r = pcall(readChunk, handle)
			if not ok then return nil end
			return r.data
		else
			return nil
		end
	end

	function stream.write(handle, data)
		rpc.call("stream_write", runtime.StreamWriteRequest.new({
			handle = handle.__handle,
			data = tostring(data),
		}))
	end

	function stream.close(handle)
		rpc.call("stream_close", runtime.StreamCloseRequest.new({
			handle = handle.__handle,
		}))
	end

	return stream
end
