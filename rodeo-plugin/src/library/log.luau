-- Logger factory — creates a per-execution logger that writes to CLI stderr via RPC.
-- Usage: local log = createLogger(rpc, "debug")

local runtime = require(script.Parent.Parent.Parent.shared.proto.runtime)

local LEVELS = { debug = 0, info = 1, warn = 2, error = 3 }

local RESET = "\27[0m"
local COLORS = {
	[0] = "\27[2m",   -- debug: dim
	[1] = "\27[36m",  -- info: cyan
	[2] = "\27[33m",  -- warn: yellow
	[3] = "\27[31m",  -- error: red
}

return function(rpc: any, level: string?)
	local minLevel = LEVELS[level or "info"] or 1

	local function write(msg: string, lvl: number)
		if lvl < minLevel then return end
		local color = COLORS[lvl] or ""
		rpc.notify("stream_write", runtime.StreamWriteRequest.new({
			handle = "stderr",
			data = color .. "[rodeo] " .. msg .. RESET .. "\n",
		}))
	end

	return {
		debug = function(msg: string) write(msg, 0) end,
		info = function(msg: string) write(msg, 1) end,
		warn = function(msg: string) write(msg, 2) end,
		error = function(msg: string) write(msg, 3) end,
	}
end
