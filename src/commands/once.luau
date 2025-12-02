-- Once command: One-off script execution in Studio

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local config = require("../library/config")
local embeddedPlugins = require("../library/plugin")
local execution = require("../library/execution")
local log = require("../library/log")
local uuid = require("../library/uuid")

local execColors = config.EXEC_LOG_COLORS

type Config = {
	scriptPath: string?,
	scriptSource: string?,
	place: string?,
	sourcemap: string?,
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	logFilter: execution.LogFilter,
	cacheRequires: boolean?,
}

type OutputMessage = {
	type: "output",
	executionId: string,
	level: "Print" | "Info" | "Warning" | "Error",
	body: string,
}

type DoneMessage = {
	type: "done",
	executionId: string,
	result: string?,
}
local CONNECTION_TIMEOUT = 60

local function parseArguments(args: any): Config
	-- Determine script source: --source flag, stdin (-), or file path
	local scriptPath = nil
	local scriptSource = args.source

	if args.script then
		if args.script == "-" then
			-- Read from stdin
			scriptSource = stdio.readToEnd()
		else
			-- File path
			scriptPath = args.script
		end
	end

	return {
		scriptPath = scriptPath,
		scriptSource = scriptSource,
		place = args.place,
		sourcemap = args.sourcemap,
		outputFile = args.output,
		returnFile = args["return"],
		showReturn = args.show_return,
		logFilter = execution.buildLogFilter(args),
		cacheRequires = args.cache_requires,
	}
end

local function validateConfig(cfg: Config)
	-- Validate that exactly one script source is provided
	if not cfg.scriptPath and not cfg.scriptSource then
		log.error("No script source provided. Use a file path, '-' for stdin, or --source for inline execution")
		process.exit(1)
	end

	if cfg.scriptPath and cfg.scriptSource then
		log.error("Cannot specify both a script file and --source flag")
		process.exit(1)
	end

	-- Validate script file exists if using file path
	if cfg.scriptPath and not fs.isFile(cfg.scriptPath) then
		log.error(`Script file not found: {cfg.scriptPath}`)
		process.exit(1)
	end

	if cfg.sourcemap and not cfg.place then
		log.error("--sourcemap requires --place to resolve instances")
		log.info("Usage: rodeo once script.luau --place game.rbxl --sourcemap sourcemap.json")
		process.exit(1)
	end

	if cfg.place and not fs.isFile(cfg.place) then
		log.error(`Place file not found: {cfg.place}`)
		process.exit(1)
	end
end

local function handlePluginConnection(
	ws: any,
	executionId: string,
	scriptContent: string,
	instancePath: string?,
	logFilter: execution.LogFilter,
	exitCodeRef: { value: number },
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	cacheRequires: boolean?
): boolean
	local message: any = {
		type = "exec",
		executionId = executionId,
		script = scriptContent,
		logFilter = logFilter,
		cacheRequires = cacheRequires,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		if decoded.type == "output" then
			local msg = decoded :: OutputMessage
			local colorFn = execColors[msg.level] or function(s)
				return s
			end
			local coloredOutput = colorFn(msg.body) .. "\n"
			execution.writeExecutionOutput(coloredOutput, outputFile)

			if msg.level == "Error" then
				exitCodeRef.value = 1
			end
		elseif decoded.type == "done" then
			local msg = decoded :: DoneMessage
			if msg.result then
				execution.writeExecutionResult(msg.result, returnFile, showReturn)
			end
			return true
		end
	end

	-- Connection closed by plugin or broken
	return true
end

local function main(args: any)
	local cfg = parseArguments(args)
	validateConfig(cfg)

	local scriptContent = execution.readScriptContent(cfg.scriptPath, cfg.scriptSource)
	local executionId = uuid.generate()
	local pluginPath = `{roblox.studioPluginPath()}/rodeo-once.rbxmx`

	local placeToOpen = cfg.place
	local tempPlacePath = nil
	if placeToOpen then
		local extension = placeToOpen:match("%.([^%.]+)$") or "rbxlx"
		local tempDir = ".rodeo/.temp"

		-- Ensure temp directory exists
		if not fs.isDir(".rodeo") then
			fs.writeDir(".rodeo")
		end
		if not fs.isDir(tempDir) then
			fs.writeDir(tempDir)
		end

		tempPlacePath = `{tempDir}/rodeo-place.{extension}`

		if fs.isFile(tempPlacePath) then
			fs.removeFile(tempPlacePath)
		end

		fs.copy(placeToOpen, tempPlacePath)
		placeToOpen = tempPlacePath
	end

	local port = args.port

	-- Write embedded plugin to Studio plugins directory
	embeddedPlugins.writeOncePlugin(pluginPath, port)

	local instancePath = execution.resolveInstancePath(cfg.sourcemap, cfg.scriptPath)

	local exitCodeRef = { value = 0 }
	local isComplete = false

	-- Start WebSocket server BEFORE launching Studio
	local server = net.serve(port, {
		handleWebSocket = function(ws)
			isComplete = handlePluginConnection(ws, executionId, scriptContent, instancePath, cfg.logFilter, exitCodeRef, cfg.outputFile, cfg.returnFile, cfg.showReturn, cfg.cacheRequires)
		end,
	})

	-- Give server a moment to start listening
	task.wait(0.5)

	-- Launch Studio
	local studioArgs = if placeToOpen then { placeToOpen } else {}
	local studioProcess = process.create(roblox.studioApplicationPath(), studioArgs)

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

	local elapsed = 0
	while not isComplete and elapsed < CONNECTION_TIMEOUT do
		task.wait(0.5)
		elapsed += 0.5
	end

	server.stop()
	pcall(function()
		studioProcess:kill()
	end)

	if fs.isFile(pluginPath) then
		fs.removeFile(pluginPath)
	end
	if tempPlacePath and fs.isFile(tempPlacePath) then
		fs.removeFile(tempPlacePath)
	end
	if fs.isDir(".rodeo/.temp") then
		fs.removeDir(".rodeo/.temp")
	end
	if fs.isDir(".rodeo") then
		fs.removeDir(".rodeo")
	end

	if not isComplete then
		log.error("Timeout waiting for execution to complete")
		process.exit(2)
	end

	process.exit(exitCodeRef.value)
end

return main
