-- @rodeo/io API over typed RPC.
local runtime = _G.__rodeo_runtime_proto

return function(rpc)
	local io = {}

	io.stdin = { __handle = "stdin" }
	io.stdout = { __handle = "stdout" }
	io.stderr = { __handle = "stderr" }

	function io.read(): string
		local resp: runtime.StreamReadLineResponse = rpc.call("stream_read_line",
			runtime.StreamReadLineRequest.new({ handle = "stdin" }))
		return resp.data
	end

	return io
end
