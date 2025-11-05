local process = require("@lune/process")
local roblox = require("@lune/roblox")

local output = require("../utils/output")
local COLORS = require("../utils/colors")
local plugin = require("../utils/plugin")
local pathfs = require("@pkg/pathfs")

local function main(_args: any)

	output.printColored(`Building serve plugin...`, COLORS.Info)

	local pluginPath = `{roblox.studioPluginPath()}/rir3-serve.rbxmx`
	local rojoProjectPath = pathfs.absolute(_G.PESDE_ROOT .. "/plugins/serve/plugin.project.json"):toString()

	plugin.generatePluginFile(pluginPath, rojoProjectPath)

	output.printColored(`Plugin installed to: {pluginPath}`, COLORS.Info)
	output.printColored(`Restart Roblox Studio to load the plugin`, COLORS.Info)

	process.exit(0)
end

return main
