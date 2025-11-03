-- Once command: One-off script execution in Studio

local net = require("@lune/net")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")
local roblox = require("@lune/roblox")

local COLORS = require("../utils/colors")
local output = require("../utils/output")
local uuid = require("../utils/uuid")
local plugin = require("../utils/plugin")

type Config = {
	script: string,
	place: string?,
	port: number,
	ignorePattern: { string },
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
}

local DEFAULT_PORT = 34872
local CONNECTION_TIMEOUT = 60

local function parseArguments(args: any): Config
	-- Args are already parsed by the router, just convert to our Config type
	return {
		script = args.script,
		place = args.place,
		port = args.port or DEFAULT_PORT,
		ignorePattern = args["ignore-pattern"] or args["ignore_pattern"] or {},
	}
end

local function validateConfig(config: Config)
	if not fs.isFile(config.script) then
		output.printError(`Script file not found: {config.script}`)
		process.exit(1)
	end

	if config.place and not fs.isFile(config.place) then
		output.printError(`Place file not found: {config.place}`)
		process.exit(1)
	end
end

local function handlePluginConnection(
	ws: any,
	executionId: string,
	scriptContent: string,
	ignorePatterns: { string },
	exitCodeRef: { value: number }
): boolean
	-- Send exec message
	ws:send(serde.encode("json", {
		type = "exec",
		executionId = executionId,
		script = scriptContent,
	}))

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
				-- Check if error matches any ignore pattern
				local shouldIgnore = false
				for _, pattern in ignorePatterns do
					if string.match(msg.body, pattern) then
						shouldIgnore = true
						stdio.write(`[Ignored error by pattern: {pattern}]\n`)
						break
					end
				end

				if not shouldIgnore then
					exitCodeRef.value = 1
				end
			end
		elseif decoded.type == "done" then
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
	local pluginPath = `{roblox.studioPluginPath()}/rir3-{config.port}.rbxmx`

	local placeToOpen = config.place
	local tempPlacePath = nil
	if placeToOpen then
		local extension = placeToOpen:match("%.([^%.]+)$") or "rbxlx"
		tempPlacePath = `/tmp/rir3-place-{config.port}.{extension}`

		if fs.isFile(tempPlacePath) then
			fs.removeFile(tempPlacePath)
		end

		fs.copy(placeToOpen, tempPlacePath)
		placeToOpen = tempPlacePath
	end

	plugin.generatePluginFile(config.port, pluginPath)

	local exitCodeRef = { value = 0 }
	local isComplete = false

	-- Start WebSocket server BEFORE launching Studio
	local server = net.serve(config.port, {
		handleWebSocket = function(ws)
			isComplete = handlePluginConnection(ws, executionId, scriptContent, config.ignorePattern or {}, exitCodeRef)
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
