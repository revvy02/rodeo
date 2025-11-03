local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local output = require("../utils/output")
local COLORS = require("../utils/colors")

type Config = {
	port: number,
}

local DEFAULT_PORT = 34872
local SERVE_TEMPLATE = "plugins/plugin_serve_template.server.luau"
local ROJO_PROJECT = "rir3-serve.project.json"

local function parseArguments(args: any): Config
	return {
		port = args.port or DEFAULT_PORT,
	}
end

local function main(args: any)
	local config = parseArguments(args)

	output.printColored(`Building serve plugin for port {config.port}...`, COLORS.Info)

	-- Create temporary Rojo project for serve plugin
	local rojoConfig = {
		name = "rir3-serve-plugin",
		tree = {
			["$path"] = SERVE_TEMPLATE,
		},
	}

	fs.writeFile(ROJO_PROJECT, serde.encode("json", rojoConfig))

	-- Build with Rojo
	local tempBuildPath = `rir3-serve-{config.port}-temp.rbxmx`
	local result = process.exec("rojo", {
		"build",
		ROJO_PROJECT,
		"-o",
		tempBuildPath,
	})

	if not result.ok then
		output.printError(`Failed to build plugin:\n{result.stderr}`)
		fs.removeFile(ROJO_PROJECT)
		process.exit(1)
	end

	-- Substitute PORT placeholder
	local template = fs.readFile(tempBuildPath)
	local pluginContent = template:gsub("{{PORT}}", tostring(config.port))

	-- Install to Studio plugins directory
	local pluginPath = `{roblox.studioPluginPath()}/rir3-serve-{config.port}.rbxmx`
	fs.writeFile(pluginPath, pluginContent)

	-- Cleanup
	fs.removeFile(tempBuildPath)
	fs.removeFile(ROJO_PROJECT)

	output.printColored(`Plugin installed to: {pluginPath}`, COLORS.Info)
	output.printColored(`Restart Roblox Studio to load the plugin`, COLORS.Info)

	process.exit(0)
end

return main
