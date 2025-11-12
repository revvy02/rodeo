local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local colors = require("./colors")

local function buildWithRojo(rojoProjectPath: string, outputPath: string): boolean
	local result = process.exec("rojo", {
		"build",
		rojoProjectPath,
		"-o",
		outputPath,
	})

	if not result.ok then
		stdio.write(colors.error(`Error: Failed to build plugin:\n{result.stderr}`) .. "\n")
		return false
	end

	return true
end

local function generatePluginFile(pluginPath: string, rojoProjectPath: string)
	-- Ensure plugin directory exists
	local pluginsDir = pluginPath:match("(.+)/[^/]+$")
	if pluginsDir and not fs.isDir(pluginsDir) then
		pcall(function()
			process.exec("mkdir", { "-p", pluginsDir })
		end)
	end

	-- Build directly to plugin path
	if not buildWithRojo(rojoProjectPath, pluginPath) then
		error("Failed to build plugin")
	end
end

return {
	buildWithRojo = buildWithRojo,
	generatePluginFile = generatePluginFile,
}
