-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances.
function roblox.import(path: string): { Instance }
	return (singleton :: any).roblox.import(path)
end

--- Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`.
function roblox.export(path: string, instances: { Instance })
	(singleton :: any).roblox.export(path, instances)
end

return roblox
