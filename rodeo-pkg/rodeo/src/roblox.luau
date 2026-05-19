-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its
--- root Instances. Useful for staging fixtures into the DataModel.
function roblox.load(path: string): { Instance }
	return (singleton :: any).roblox.load(path)
end

return roblox
