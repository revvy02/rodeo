local process = require("@lune/process")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

local colors = require("../utils/colors")
local pathfs = require("@pkg/pathfs")
local plugin = require("../utils/plugin")

local function main(_args: any)
	stdio.write(colors.cyan("Building serve plugin...") .. "\n")

	local pluginPath = `{roblox.studioPluginPath()}/rodeo-serve.rbxmx`
	local rojoProjectPath = pathfs.absolute(_G.PESDE_ROOT .. "/plugins/serve/plugin.project.json"):toString()

	plugin.generatePluginFile(pluginPath, rojoProjectPath)

	stdio.write(colors.cyan(`Plugin installed to: {pluginPath}`) .. "\n")
	stdio.write(colors.cyan("Restart Roblox Studio to load the plugin") .. "\n")

	process.exit(0)
end

return main
