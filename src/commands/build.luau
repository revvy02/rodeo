local process = require("@lune/process")
local roblox = require("@lune/roblox")

local output = require("../utils/output")
local COLORS = require("../utils/colors")
local plugin = require("../utils/plugin")

local function main(_args: any)

	output.printColored(`Building serve plugin...`, COLORS.Info)

	local pluginPath = `{roblox.studioPluginPath()}/rir3-serve.rbxmx`
	local rojoProjectPath = _G.PESDE_ROOT .. "/plugins/serve/default.project.json"

	local success = pcall(function()
		plugin.generatePluginFile(pluginPath, rojoProjectPath)
	end)

	if not success then
		process.exit(1)
	end

	output.printColored(`Plugin installed to: {pluginPath}`, COLORS.Info)
	output.printColored(`Restart Roblox Studio to load the plugin`, COLORS.Info)

	process.exit(0)
end

return main
