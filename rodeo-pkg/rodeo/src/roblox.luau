-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its
--- root Instances. Useful for staging fixtures into the DataModel.
function roblox.load(path: string): { Instance }
	return (singleton :: any).roblox.load(path)
end

--- Reads the model file at `path` and deserializes it via
--- `SerializationService:DeserializeInstancesAsync`. Returns the root
--- Instances. Symmetric with `export`.
function roblox.import(path: string): { Instance }
	return (singleton :: any).roblox.import(path)
end

--- Serializes `instances` via `SerializationService:SerializeInstancesAsync`
--- and writes the resulting model bytes to `path`. Symmetric with `import`.
function roblox.export(instances: { Instance }, path: string)
	(singleton :: any).roblox.export(instances, path)
end

return roblox
