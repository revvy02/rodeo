-- script to convert a standard roblox project directory to a darklua out directory
-- usage: lune run dark_rojo <src_path> <config_path>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local srcPath = process.args[1]
local configPath = process.args[2]

if not srcPath or not configPath then
	print("Usage: lune run dark_rojo <src_path> <config_path>")
	process.exit(1)
end

-- Get parent directory of srcPath and the src folder name
local parentDir = srcPath:match("(.+)/") or "."
local srcFolder = srcPath:match(".+/(.+)") or srcPath

-- Generate sourcemap from parent directory's project (darklua needs this)
process.exec("rojo", { "sourcemap", parentDir .. "/default.project.json", "-o", parentDir .. "/sourcemap.json" }, { stdio = "forward" })

-- Create out directory
if fs.isDir("out") then
	fs.removeDir("out")
end
fs.writeDir("out")

-- Create parent dir in out/ if needed
if parentDir ~= "." then
	fs.writeDir("out/" .. parentDir)
end

-- Mutate project file: prepend ../ to $path values that aren't the src folder
local function mutatePaths(node: any)
	if type(node) ~= "table" then
		return
	end
	for key, value in node do
		if key == "$path" and type(value) == "string" then
			if value ~= srcFolder then
				node[key] = "../" .. value
			end
		elseif type(value) == "table" then
			mutatePaths(value)
		end
	end
end

local projectJson = serde.decode("json", fs.readFile(parentDir .. "/default.project.json"))
mutatePaths(projectJson.tree)
fs.writeFile("out/" .. parentDir .. "/default.project.json", serde.encode("json", projectJson))

-- Run darklua: srcPath -> out/srcPath (maintains hierarchy)
process.exec("darklua", { "process", srcPath, "out/" .. srcPath, "--config", configPath }, { stdio = "forward" })
