-- Roblox-flavored helpers — `.rbxm` loading and MCP tool calls.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its
--- root Instances. Useful for staging fixtures into the DataModel.
function roblox.load(path: string): { Instance }
	return (singleton :: any).roblox.load(path)
end

-- mcp.* helpers live on a sub-table; declared via wrapper function form
-- so each one renders as its own doc entry.
roblox.mcp = {}

--- Invokes an MCP tool by name with optional arguments, returning the
--- string response. Routes through the StudioMCP bridge.
function roblox.mcp.call(tool: string, arguments: { [string]: any }?): string
	return (singleton :: any).roblox.mcp.call(tool, arguments)
end

return roblox
