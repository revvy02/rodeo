local process = require("@lune/process")
local roblox = require("@lune/roblox")

local output = require("../utils/output")
local COLORS = require("../utils/colors")
local plugin = require("../utils/plugin")

type Config = {
	port: number,
}

local DEFAULT_PORT = 34872

local function parseArguments(args: any): Config
	return {
		port = args.port or DEFAULT_PORT,
	}
end

local function main(args: any)
	local config = parseArguments(args)

	output.printColored(`Building serve plugin for port {config.port}...`, COLORS.Info)

	local pluginPath = `{roblox.studioPluginPath()}/rir3-serve-{config.port}.rbxmx`
	local templatePath = _G.PESDE_ROOT .. "/plugins/plugin_serve_template.server.luau"

	local success = pcall(function()
		plugin.generatePluginFile(config.port, pluginPath, templatePath)
	end)

	if not success then
		process.exit(1)
	end

	output.printColored(`Plugin installed to: {pluginPath}`, COLORS.Info)
	output.printColored(`Restart Roblox Studio to load the plugin`, COLORS.Info)

	process.exit(0)
end

return main
