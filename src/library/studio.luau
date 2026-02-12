-- Studio instance launch and lifecycle management
-- Shared by serve --launch and once commands

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local embeddedPlugins = require("./plugin")
local log = require("./log")

export type LaunchOptions = {
	port: number,
	place: string?,
}

export type StudioInstance = {
	process: any,
	pluginPath: string,
	tempPlacePath: string?,
	tempDir: string,
	kill: (self: StudioInstance) -> (),
	cleanup: (self: StudioInstance) -> (),
}

local StudioInstance = {}
StudioInstance.__index = StudioInstance

function StudioInstance:kill()
	pcall(function()
		self.process:kill()
	end)
end

function StudioInstance:cleanup()
	self:kill()

	if fs.isFile(self.pluginPath) then
		fs.removeFile(self.pluginPath)
	end
	if self.tempPlacePath and fs.isFile(self.tempPlacePath) then
		fs.removeFile(self.tempPlacePath)
	end
	if fs.isDir(self.tempDir) then
		fs.removeDir(self.tempDir)
	end
	-- Clean up parent .rodeo dir if empty
	local parentDir = string.match(self.tempDir, "(.+)/[^/]+$")
	if parentDir and fs.isDir(parentDir) then
		-- Only remove if empty (pcall in case it has other contents)
		pcall(fs.removeDir, parentDir)
	end
end

-- Create a temp place file, optionally from an existing place file.
-- Patches the workspace with a session ID attribute for plugin identification.
local function createTempPlace(options: LaunchOptions): string
	local tempDir = ".rodeo/.temp"

	-- Ensure temp directory exists
	if not fs.isDir(".rodeo") then
		fs.writeDir(".rodeo")
	end
	if not fs.isDir(tempDir) then
		fs.writeDir(tempDir)
	end

	local tempPlacePath: string

	if options.place then
		-- Copy provided place file
		local extension = options.place:match("%.([^%.]+)$") or "rbxlx"
		tempPlacePath = `{tempDir}/rodeo-place.{extension}`

		if fs.isFile(tempPlacePath) then
			fs.removeFile(tempPlacePath)
		end

		fs.copy(options.place, tempPlacePath)
	else
		-- Create empty place file
		tempPlacePath = `{tempDir}/rodeo-place.rbxlx`
	end

	-- Serialize a valid place file
	local game
	if options.place then
		game = roblox.deserializePlace(fs.readFile(tempPlacePath))
	else
		game = roblox.Instance.new("DataModel")
		local ws = roblox.Instance.new("Workspace")
		ws.Parent = game
	end

	fs.writeFile(tempPlacePath, roblox.serializePlace(game))

	return tempPlacePath
end

-- Launch a Studio instance with a baked-in plugin targeting the given port.
-- Returns a StudioInstance handle for lifecycle management.
local function launch(options: LaunchOptions): StudioInstance
	local pluginPath = `{roblox.studioPluginPath()}/rodeo-launch-{options.port}.rbxmx`
	local tempDir = ".rodeo/.temp"

	-- Create temp place
	local tempPlacePath = createTempPlace(options)

	-- Write embedded plugin with port baked in
	embeddedPlugins.writeOncePlugin(pluginPath, options.port)

	-- Launch Studio
	log.info(`Launching Studio on port {options.port}...`)
	local studioProcess = process.create(roblox.studioApplicationPath(), { tempPlacePath })

	-- Drain stdout/stderr to prevent Studio from blocking on full pipe buffers
	task.spawn(function()
		while studioProcess.stdout:read() do
			continue
		end
	end)
	task.spawn(function()
		while studioProcess.stderr:read() do
			continue
		end
	end)

	local instance = setmetatable({
		process = studioProcess,
		pluginPath = pluginPath,
		tempPlacePath = tempPlacePath,
		tempDir = tempDir,
	}, StudioInstance)

	return (instance :: any) :: StudioInstance
end

return {
	launch = launch,
	createTempPlace = createTempPlace,
}
