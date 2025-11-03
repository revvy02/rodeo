local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local output = require("./output")

local plugin = {}

local ROJO_PROJECT_FILE = _G.PESDE_ROOT .. "/rir3.project.json"

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

function plugin.generatePluginFile(port: number, pluginPath: string, templatePath: string?)
	local tempBuildPath = `rir3-{port}-temp.rbxmx`
	local rojoProjectPath = ROJO_PROJECT_FILE
	local needsCleanup = false

	-- If a template path is provided, create a temporary Rojo project
	if templatePath then
		rojoProjectPath = `rir3-{port}-temp.project.json`
		needsCleanup = true

		local rojoConfig = {
			name = "rir3-plugin",
			tree = {
				["$path"] = templatePath,
			},
		}

		fs.writeFile(rojoProjectPath, serde.encode("json", rojoConfig))
	end

	if not plugin.buildWithRojo(rojoProjectPath, tempBuildPath) then
		if needsCleanup then
			pcall(fs.removeFile, rojoProjectPath)
		end
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

	if needsCleanup then
		pcall(fs.removeFile, rojoProjectPath)
	end
end

return plugin
