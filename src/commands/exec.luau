-- Exec command: Execute script via persistent serve server

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = require("../utils/colors")
local constants = require("../utils/constants")
local execution = require("../utils/execution")
local uuid = require("../utils/uuid")

type Config = {
	scriptPath: string?,
	scriptSource: string?,
	sourcemap: string?,
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	filterBits: number,
	filterMask: number,
	logFilter: execution.LogFilter,
	cacheRequires: boolean?,
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
		sourcemap = args.sourcemap,
		outputFile = args.output,
		returnFile = args["return"],
		showReturn = args.show_return,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = execution.buildLogFilter(args),
		cacheRequires = args.cache_requires,
	}
end

local function validateConfig(config: Config)
	-- Validate that exactly one script source is provided
	if not config.scriptPath and not config.scriptSource then
		stdio.write(colors.error("Error: No script source provided. Use a file path, '-' for stdin, or --source for inline execution") .. "\n")
		process.exit(1)
	end

	if config.scriptPath and config.scriptSource then
		stdio.write(colors.error("Error: Cannot specify both a script file and --source flag") .. "\n")
		process.exit(1)
	end

	-- Validate script file exists if using file path
	if config.scriptPath and not fs.isFile(config.scriptPath) then
		stdio.write(colors.error(`Error: Script file not found: {config.scriptPath}`) .. "\n")
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

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter, cacheRequires: boolean?)
	local message: any = {
		type = "submit",
		script = script,
		executionId = executionId,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = logFilter,
		cacheRequires = cacheRequires,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))
end

local function handleMessage(decoded: any, exitCodeRef: { value: number }, outputFile: string?, returnFile: string?, showReturn: boolean?): boolean
	if decoded.type == "queued" then
		if decoded.waiting then
			stdio.write(colors.cyan(`Waiting: {decoded.waiting}`) .. "\n")
		elseif decoded.matches then
			-- Queued successfully to matching studios
		end
	elseif decoded.type == "output" then
		local colorFn = colors.levelColors[decoded.level] or function(s) return s end
		local coloredOutput = colorFn(decoded.body) .. "\n"
		execution.writeExecutionOutput(coloredOutput, outputFile)
		if decoded.level == "Error" then
			exitCodeRef.value = 1
		end
	elseif decoded.type == "done" then
		if decoded.result then
			execution.writeExecutionResult(decoded.result, returnFile, showReturn)
		end
		return true
	elseif decoded.type == "disconnect" then
		stdio.write(colors.error("Error: Studio disconnected") .. "\n")
		exitCodeRef.value = 2
		return true
	end

	return false
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	if not checkServerHealth(constants.SERVE_PORT) then
		stdio.write(colors.error(`Error: No rir3 server found on port {constants.SERVE_PORT}. Run 'rir3 serve' first.`) .. "\n")
		process.exit(1)
	end

	local instancePath = execution.resolveInstancePath(config.sourcemap, config.scriptPath)
	local scriptContent = execution.readScriptContent(config.scriptPath, config.scriptSource)
	local executionId = uuid.generate()
	local exitCodeRef = { value = 0 }

	local ws = connectToServer(constants.SERVE_PORT)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath, config.filterBits, config.filterMask, config.logFilter, config.cacheRequires)

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)
		local isDone = handleMessage(decoded, exitCodeRef, config.outputFile, config.returnFile, config.showReturn)

		if isDone then
			ws:close()
			break
		end
	end

	process.exit(exitCodeRef.value)
end

return main
