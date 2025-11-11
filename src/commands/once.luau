-- Once command: One-off script execution in Studio

local fs = require("@lune/fs")
local net = require("@lune/net")
local pathfs = require("@pkg/pathfs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local COLORS = require("../utils/colors")
local constants = require("../utils/constants")
local output = require("../utils/output")
local plugin = require("../utils/plugin")
local sourcemap = require("../utils/sourcemap")
local uuid = require("../utils/uuid")

type Config = {
	script: string,
	place: string?,
	sourcemap: string?,
	output: string?,
	logFilter: LogFilter,
}

type LogFilter = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
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
	-- Args are already parsed by the router, just convert to our Config type
	local noLogs = args["no_logs"] or false

	return {
		script = args.script,
		place = args.place,
		sourcemap = args.sourcemap,
		output = args.output,
		logFilter = {
			enableWarn = not (args["no_warn"] or noLogs),
			enableError = not (args["no_error"] or noLogs),
			enableInfo = not (args["no_info"] or noLogs),
			enableOutput = not (args["no_output"] or noLogs),
			enableLogs = not noLogs,
		},
	}
end

local function validateConfig(config: Config)
	if not fs.isFile(config.script) then
		output.printError(`Script file not found: {config.script}`)
		process.exit(1)
	end

	if config.sourcemap and not config.place then
		output.printError("--sourcemap requires --place to resolve instances")
		output.printInfo("Usage: rir3 once script.luau --place game.rbxl --sourcemap sourcemap.json")
		process.exit(1)
	end

	if config.place and not fs.isFile(config.place) then
		output.printError(`Place file not found: {config.place}`)
		process.exit(1)
	end
end

local function handlePluginConnection(ws: any, executionId: string, scriptContent: string, instancePath: string?, logFilter: LogFilter, exitCodeRef: { value: number }, outputPath: string?): boolean
	local message: any = {
		type = "exec",
		executionId = executionId,
		script = scriptContent,
		logFilter = logFilter,
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
			output.printColored(msg.body, COLORS[msg.level] or COLORS.Print)

			if msg.level == "Error" then
				exitCodeRef.value = 1
			end
		elseif decoded.type == "done" then
			local msg = decoded :: DoneMessage
			if msg.result then
				if outputPath then
					fs.writeFile(outputPath, msg.result)
				else
					stdio.write(msg.result)
					stdio.write("\n")
				end
			end
			return true
		end
	end

	-- Connection closed by plugin or broken
	return true
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	local scriptContent = fs.readFile(config.script)
	local executionId = uuid.generate()
	local pluginPath = `{roblox.studioPluginPath()}/rir3-once.rbxmx`
	local rojoProjectPath = pathfs.absolute(_G.PESDE_ROOT .. "/plugins/once/plugin.project.json"):toString()

	local placeToOpen = config.place
	local tempPlacePath = nil
	if placeToOpen then
		local extension = placeToOpen:match("%.([^%.]+)$") or "rbxlx"
		tempPlacePath = `/tmp/rir3-place.{extension}`

		if fs.isFile(tempPlacePath) then
			fs.removeFile(tempPlacePath)
		end

		fs.copy(placeToOpen, tempPlacePath)
		placeToOpen = tempPlacePath
	end

	plugin.generatePluginFile(pluginPath, rojoProjectPath)

	local instancePath: string? = nil
	if config.sourcemap then
		local map, err = sourcemap.loadSourcemap(config.sourcemap)
		if not map then
			output.printError(err or "Failed to load sourcemap")
			process.exit(1)
		end

		instancePath = sourcemap.findInstancePath(map, config.script)
		if not instancePath then
			output.printWarning(`Script not found in sourcemap: {config.script}`)
			output.printInfo("Falling back to temporary module execution")
		end
	end

	local exitCodeRef = { value = 0 }
	local isComplete = false

	-- Start WebSocket server BEFORE launching Studio
	local server = net.serve(constants.ONCE_PORT, {
		handleWebSocket = function(ws)
			isComplete = handlePluginConnection(ws, executionId, scriptContent, instancePath, config.logFilter, exitCodeRef, config.output)
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

	if not isComplete then
		output.printError("Timeout waiting for execution to complete")
		process.exit(2)
	end

	process.exit(exitCodeRef.value)
end

return main
