local process = require("@lune/process")

local ok = require("./lune_packages/scripts_core").generators.rojo.sourcemap(process.args[1])

if not ok then
	return process.exit(1)
end