-- Standard input/output handles available inside Studio scripts.
-- Bundled require: `local io = require("@rodeo/io")`.

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

local io = {}

-- stdin/stdout/stderr are value handles, not callables. Declared as typed
-- fields here so consumers see them via autocomplete; the actual runtime
-- values are populated by the plugin's shim (rodeo-pkg/shims/io.luau).
-- The `:: any :: T` shape narrows the type without producing a real value
-- at typedef-evaluation time.

--- Standard input stream handle. Pass to `stream.read` to read from stdin.
io.stdin = (nil :: any) :: shared.StreamHandle

--- Standard output stream handle. Pass to `stream.write` to write to stdout.
io.stdout = (nil :: any) :: shared.StreamHandle

--- Standard error stream handle. Pass to `stream.write` to write to stderr.
io.stderr = (nil :: any) :: shared.StreamHandle

--- Reads a line from stdin (blocking). Returns the line without trailing newline.
function io.read(): string
	return (singleton :: any).io.read()
end

return io
