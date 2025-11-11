-- Exec command: Execute script via persistent serve server

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local COLORS = require("../utils/colors")
local constants = require("../utils/constants")
local output = require("../utils/output")
local sourcemap = require("../utils/sourcemap")
local uuid = require("../utils/uuid")

type Config = {
	script: string,
	sourcemap: string?,
	output: string?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter,
}

type LogFilter = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

local function parseContextFlags(args: any): (number, number)
	local filterBits = 0
	local filterMask = 0

	local contextMap = {
		studio = constants.CONTEXT_BITS.isStudio,
		client = constants.CONTEXT_BITS.isClient,
		server = constants.CONTEXT_BITS.isServer,
		edit = constants.CONTEXT_BITS.isEdit,
		running = constants.CONTEXT_BITS.isRunning,
	}

	for flagName, bitPos in pairs(contextMap) do
		local value = args[flagName]
		if value ~= nil then
			local bitMask = bit32.lshift(1, bitPos)
			filterMask = bit32.bor(filterMask, bitMask)

			if value == 1 then
				filterBits = bit32.bor(filterBits, bitMask)
			elseif value == 0 then
				filterBits = bit32.band(filterBits, bit32.bnot(bitMask))
			end
		end
	end

	return filterBits, filterMask
end

local function parseArguments(args: any): Config
	local filterBits, filterMask = parseContextFlags(args)
	local noLogs = args["no_logs"] or false

	return {
		script = args.script,
		sourcemap = args.sourcemap,
		output = args.output,
		filterBits = filterBits,
		filterMask = filterMask,
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
end

local function checkServerHealth(port: number): boolean
	local success, response = pcall(function()
		return net.request({
			url = `http://localhost:{port}/health`,
			method = "GET",
		})
	end)

	return success and response.ok
end

local function connectToServer(port: number): any
	return net.socket(`ws://localhost:{port}`)
end

local function identifyClient(ws: any)
	ws:send(serde.encode("json", {
		clientType = "exec",
	}))
end

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter)
	local message: any = {
		type = "submit",
		script = script,
		executionId = executionId,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = logFilter,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))
end

local function handleMessage(decoded: any, exitCodeRef: { value: number }, outputPath: string?): boolean
	if decoded.type == "queued" then
		if decoded.waiting then
			output.printColored(`Waiting: {decoded.waiting}`, COLORS.Info)
		elseif decoded.matches then
			-- Queued successfully to matching studios
		end
	elseif decoded.type == "output" then
		output.printColored(decoded.body, COLORS[decoded.level] or COLORS.Print)
		if decoded.level == "Error" then
			exitCodeRef.value = 1
		end
	elseif decoded.type == "done" then
		if decoded.result then
			if outputPath then
				fs.writeFile(outputPath, decoded.result)
			else
				stdio.write(decoded.result)
				stdio.write("\n")
			end
		end
		return true
	elseif decoded.type == "disconnect" then
		output.printError("Studio disconnected")
		exitCodeRef.value = 2
		return true
	end

	return false
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	if not checkServerHealth(constants.SERVE_PORT) then
		output.printError(`No rir3 server found on port {constants.SERVE_PORT}. Run 'rir3 serve' first.`)
		process.exit(1)
	end

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

	local scriptContent = fs.readFile(config.script)
	local executionId = uuid.generate()
	local exitCodeRef = { value = 0 }

	local ws = connectToServer(constants.SERVE_PORT)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath, config.filterBits, config.filterMask, config.logFilter)

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)
		local isDone = handleMessage(decoded, exitCodeRef, config.output)

		if isDone then
			ws:close()
			break
		end
	end

	process.exit(exitCodeRef.value)
end

return main
