-- Standard input/output handles available inside Studio scripts.
-- Bundled require: `local io = require("@rodeo/io")`.

local singleton = require("./_internal/singleton")
local stream = require("./stream")

local io = {}

-- stdin/stdout/stderr are value handles, not callables. Declared as typed
-- fields here so consumers see them via autocomplete; the actual runtime
-- values are populated by the plugin's shim (rodeo-pkg/rodeo/shims/io.luau).

--- Standard input stream handle. Pass to `stream.read` to read from stdin.
io.stdin = (nil :: any) :: stream.StreamHandle

--- Standard output stream handle. Pass to `stream.write` to write to stdout.
io.stdout = (nil :: any) :: stream.StreamHandle

--- Standard error stream handle. Pass to `stream.write` to write to stderr.
io.stderr = (nil :: any) :: stream.StreamHandle

--- Reads a line from stdin (blocking). Returns the line without trailing newline.
function io.read(): string
	return (singleton :: any).io.read()
end

return io
