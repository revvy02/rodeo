local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
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

function plugin.generatePluginFile(port: number, pluginPath: string, templatePath: string)
	local tempBuildPath = `rir3-{port}-temp.rbxmx`
	local rojoProjectPath = `rir3-{port}-temp.project.json`

	-- Create temporary Rojo project
	local rojoConfig = {
		name = "rir3-plugin",
		tree = {
			["$path"] = templatePath,
		},
	}

	fs.writeFile(rojoProjectPath, serde.encode("json", rojoConfig))

	if not plugin.buildWithRojo(rojoProjectPath, tempBuildPath) then
		pcall(fs.removeFile, rojoProjectPath)
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
	fs.removeFile(rojoProjectPath)
end

return plugin
