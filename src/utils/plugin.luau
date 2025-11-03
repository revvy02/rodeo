local process = require("@lune/process")
local fs = require("@lune/fs")
local output = require("./output")

local plugin = {}

function plugin.buildWithRojo(rojoProjectPath: string, outputPath: string): boolean
	local result = process.exec("rojo", {
		"build",
		rojoProjectPath,
		"-o",
		outputPath,
	})

	if not result.ok then
		output.printError(`Failed to build plugin:\n{result.stderr}`)
		return false
	end

	return true
end

function plugin.generatePluginFile(pluginPath: string, rojoProjectPath: string)
	-- Ensure plugin directory exists
	local pluginsDir = pluginPath:match("(.+)/[^/]+$")
	if pluginsDir and not fs.isDir(pluginsDir) then
		pcall(function()
			process.exec("mkdir", { "-p", pluginsDir })
		end)
	end

	-- Build directly to plugin path
	if not plugin.buildWithRojo(rojoProjectPath, pluginPath) then
		error("Failed to build plugin")
	end
end

return plugin
