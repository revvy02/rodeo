local process = require("@lune/process")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

local colors = require("../utils/colors")
local embeddedPlugins = require("../utils/plugin")

local function main(_args: any)
	stdio.write(colors.cyan("Installing serve plugin...") .. "\n")

	local pluginPath = `{roblox.studioPluginPath()}/rodeo-serve.rbxmx`

	-- Write embedded plugin to Studio plugins directory
	embeddedPlugins.writeServePlugin(pluginPath)

	stdio.write(colors.cyan(`Plugin installed to: {pluginPath}`) .. "\n")
	stdio.write(colors.cyan("Restart Roblox Studio to load the plugin") .. "\n")

	process.exit(0)
end

return main
