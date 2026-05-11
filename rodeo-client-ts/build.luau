-- Generate TS proto bindings (wraps `bun run generate` which invokes buf).
-- Invoked from repo root (cwd = repo root):
--   lune run rodeo-client-ts/build

local process = require("@lune/process")

print("Generating TS proto types...")
process.exec("bun", { "run", "generate" }, {
	stdio = "forward",
	cwd = "rodeo-client-ts",
})

print("TS proto gen complete.")
