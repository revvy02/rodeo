local process = require("@lune/process")
local fs = require("@lune/fs")
local output = require("./output")

local plugin = {}

local ROJO_PROJECT_FILE = "rir3.project.json"

function plugin.buildWithRojo(outputPath: string): boolean
	local result = process.exec("rojo", {
		"build",
		ROJO_PROJECT_FILE,
		"-o",
		outputPath,
	})

	if not result.ok then
		output.printError(`Failed to build plugin:\n{result.stderr}`)
		return false
	end

	return true
end

function plugin.generatePluginFile(port: number, pluginPath: string, templatePath: string?)
	local tempBuildPath = `rir3-{port}-temp.rbxmx`

	if not plugin.buildWithRojo(tempBuildPath) then
		error("Failed to build plugin")
	end

	local template = fs.readFile(tempBuildPath)
	local pluginContent = template:gsub("{{PORT}}", tostring(port))

	local pluginsDir = pluginPath:match("(.+)/[^/]+$")
	if pluginsDir and not fs.isDir(pluginsDir) then
		pcall(function()
			process.exec("mkdir", { "-p", pluginsDir })
		end)
	end

	fs.writeFile(pluginPath, pluginContent)
	fs.removeFile(tempBuildPath)
end

return plugin
