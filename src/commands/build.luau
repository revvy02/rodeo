local process = require("@lune/process")
local roblox = require("@lune/roblox")

local embeddedPlugins = require("../library/plugin")
local log = require("../library/log")

local function main(_args: any)
	log.info("Installing serve plugin...")

	local pluginPath = `{roblox.studioPluginPath()}/rodeo-serve.rbxmx`

	-- Write embedded plugin to Studio plugins directory
	embeddedPlugins.writeServePlugin(pluginPath)

	log.info(`Plugin installed to: {pluginPath}`)
	log.info("Restart Roblox Studio to load the plugin")

	process.exit(0)
end

return main
