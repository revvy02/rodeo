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

	-- Each write is one RPC message to the host; oversized messages sever the
	-- WS connection (or are refused by the WS client) instead of erroring, so
	-- large payloads are split into chunks. (repeat/until so an empty write
	-- still makes one call, matching the unchunked behavior.)
	-- 4MB leaves room for JSON escaping inflation (~2x worst case) inside the
	-- envelope before the WS server's 16MB frame cap.
	local WRITE_CHUNK = 4 * 1024 * 1024

	function stream.write(handle, data)
		local s = tostring(data)
		local len = #s
		local offset = 1
		repeat
			local last = math.min(offset + WRITE_CHUNK - 1, len)
			if last < len then
				-- Cuts must land on codepoint boundaries: every hop (the RPC
				-- JSONEncode, WS text frames, serde on the host) rejects
				-- invalid UTF-8, and a chunk holding half a codepoint hangs
				-- the call. utf8.offset(0) gives the start of the codepoint
				-- containing the byte after the cut; if that codepoint
				-- straddles the cut, end the chunk just before it. (The
				-- offset guard keeps progress on non-UTF-8 data, which the
				-- transport rejects regardless.)
				local cpStart = utf8.offset(s, 0, last + 1)
				if cpStart ~= nil and cpStart > offset then
					last = cpStart - 1
				end
			end
			rpc.call("stream_write", runtime.StreamWriteRequest.new({
				handle = handle.__handle,
				data = string.sub(s, offset, last),
			}))
			offset = last + 1
		until offset > len
	end

	function stream.readBytes(handle): buffer
		local r: runtime.StreamReadBytesResponse = rpc.call("stream_read_bytes", runtime.StreamReadBytesRequest.new({
			handle = handle.__handle,
		}))
		return r.data
	end

	function stream.writeBytes(handle, data: buffer)
		rpc.call("stream_write_bytes", runtime.StreamWriteBytesRequest.new({
			handle = handle.__handle,
			data = data,
		}))
	end

	function stream.close(handle)
		rpc.call("stream_close", runtime.StreamCloseRequest.new({
			handle = handle.__handle,
		}))
	end

	return stream
end
