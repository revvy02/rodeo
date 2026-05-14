-- Stream read/write/close primitives for handles returned by fs.open, io
-- stdio, and process.create stdio.
-- Bundled require: `local stream = require("@rodeo/stream")`.

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

export type Stream = {
	read: (handle: shared.StreamHandle) -> string?,
	write: (handle: shared.StreamHandle, data: any) -> (),
	close: (handle: shared.StreamHandle) -> (),
}

return (singleton :: any).stream :: Stream
