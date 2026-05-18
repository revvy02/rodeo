-- Stream read/write/close primitives for handles returned by `fs.open`,
-- `io` stdio handles, and `process.create` stdio.
-- Bundled require: `local stream = require("@rodeo/stream")`.

local singleton = require("./_internal/singleton")
local shared = require("./types")

local stream = {}

--- Reads from `handle`. Returns the next chunk as a string, or `nil` on EOF.
function stream.read(handle: shared.StreamHandle): string?
	return (singleton :: any).stream.read(handle)
end

--- Writes `data` to `handle`. `data` is converted to a string via `tostring`.
function stream.write(handle: shared.StreamHandle, data: any)
	(singleton :: any).stream.write(handle, data)
end

--- Closes `handle`. Subsequent reads/writes error.
function stream.close(handle: shared.StreamHandle)
	(singleton :: any).stream.close(handle)
end

return stream
