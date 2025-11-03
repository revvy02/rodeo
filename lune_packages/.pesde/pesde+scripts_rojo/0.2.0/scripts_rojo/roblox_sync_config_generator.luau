local process = require("@lune/process")

local args = table.clone(process.args)
local ok, _ = require("./lune_packages/scripts_core").generators.rojo.syncConfig(table.remove(args, 1), args, { writeToFile = true })

if not ok then 
	return process.exit(1)
end