-- Standard input/output handles available inside Studio scripts.
-- Bundled require: `local io = require("@rodeo/io")`.

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

export type Io = {
	stdin: shared.StreamHandle,
	stdout: shared.StreamHandle,
	stderr: shared.StreamHandle,
	read: () -> string,
}

return (singleton :: any).io :: Io
