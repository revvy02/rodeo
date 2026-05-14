-- Roblox-flavored helpers (load .rbxm files, call MCP tools) available
-- inside Studio scripts.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

export type Roblox = {
	load: (path: string) -> { Instance },
	mcp: {
		call: (tool: string, arguments: { [string]: any }?) -> string,
	},
}

return (singleton :: any).roblox :: Roblox
