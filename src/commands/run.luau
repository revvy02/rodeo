-- Run command: Run script via persistent serve server

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local pathfs = require("@pkg/pathfs")

local config = require("../library/config")
local directive = require("../library/directive")
local execution = require("../library/execution")
local log = require("../library/log")
local uuid = require("../library/uuid")

local execColors = config.EXEC_LOG_COLORS

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
	context: string,
}

local function parseContextFlags(args: any): (number, number)
	local filterBits = 0
	local filterMask = 0

	local contextMap = {
		studio = config.CONTEXT_BITS.isStudio,
		client = config.CONTEXT_BITS.isClient,
		server = config.CONTEXT_BITS.isServer,
		edit = config.CONTEXT_BITS.isEdit,
		running = config.CONTEXT_BITS.isRunning,
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

local function parseDirective(content: string): { [string]: any }?
	-- Check first line (or second if shebang)
	local lines = string.split(content, "\n")
	local directiveLine = lines[1]

	if directiveLine and string.sub(directiveLine, 1, 2) == "#!" and lines[2] then
		directiveLine = lines[2]
	end

	if not directiveLine then
		return nil
	end

	-- Match @rodeo run directive (-- @rodeo run or --@rodeo run)
	local directiveStr = string.match(directiveLine, "^%-%-%s*@rodeo%s+run%s+(.+)$")
	if not directiveStr then
		return nil
	end

	return directive.parseDirectiveFlags(directiveStr)
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
			-- Resolve script path (checks .rodeo/ for simple names)
			scriptPath = directive.resolveScriptPath(args.script)
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
		context = args.context,
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
end

local function checkServerHealth(host: string, port: number): boolean
	local success, response = pcall(function()
		return net.request({
			url = `http://{host}:{port}/health`,
			method = "GET",
		})
	end)

	return success and response.ok
end

local function connectToServer(host: string, port: number): any
	return net.socket(`ws://{host}:{port}`)
end

local function identifyClient(ws: any)
	ws:send(serde.encode("json", {
		clientType = "exec",
	}))
end

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?, scriptPath: string?, filterBits: number, filterMask: number, logFilter: LogFilter, cacheRequires: boolean?, context: string)
	local message: any = {
		type = "submit",
		script = script,
		executionId = executionId,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = logFilter,
		cacheRequires = cacheRequires,
		context = context,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	if scriptPath then
		message.scriptPath = scriptPath
	end

	ws:send(serde.encode("json", message))
end

local function handleMessage(decoded: any, exitCodeRef: { value: number }, outputFile: string?, returnFile: string?, showReturn: boolean?): boolean
	if decoded.type == "queued" then
		if decoded.waiting then
			log.info(`Waiting: {decoded.waiting}`)
		elseif decoded.matches then
			-- Queued successfully to matching studios
		end
	elseif decoded.type == "output" then
		local colorFn = execColors[decoded.level] or function(s)
			return s
		end
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
		log.error("Studio disconnected")
		exitCodeRef.value = 2
		return true
	end

	return false
end

local function main(args: any)
	-- Resolve script path first (for .rodeo/ lookup)
	local scriptPath = nil
	local scriptSource = args.source

	if args.script then
		if args.script == "-" then
			scriptSource = stdio.readToEnd()
		else
			scriptPath = directive.resolveScriptPath(args.script)
		end
	end

	-- Read script content early to parse directives
	local scriptContent = execution.readScriptContent(scriptPath, scriptSource)

	-- Parse and apply directives from script (CLI args override)
	local parsedDirective = parseDirective(scriptContent)
	if parsedDirective then
		directive.applyDirective(args, parsedDirective)
	end

	-- Now parse arguments with directive defaults applied
	local cfg = parseArguments(args)
	validateConfig(cfg)

	local host = args.host
	local port = args.port

	if not checkServerHealth(host, port) then
		log.error(`No rodeo server found at {host}:{port}. Run 'rodeo serve --port {port}' first.`)
		process.exit(1)
	end

	local instancePath = execution.resolveInstancePath(cfg.sourcemap, scriptPath)
	local executionId = uuid.generate()
	local exitCodeRef = { value = 0 }

	-- Compute relative path from cwd for module naming in Studio
	local relativePath: string? = nil
	if scriptPath then
		local absolutePath = pathfs.absolute(scriptPath)
		local cwdPath = pathfs.cwd()
		local diff = pathfs.diff(absolutePath, cwdPath)
		relativePath = if diff then diff:toString() else scriptPath
	end

	local ws = connectToServer(host, port)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath, relativePath, cfg.filterBits, cfg.filterMask, cfg.logFilter, cfg.cacheRequires, cfg.context)

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)
		local isDone = handleMessage(decoded, exitCodeRef, cfg.outputFile, cfg.returnFile, cfg.showReturn)

		if isDone then
			ws:close()
			break
		end
	end

	process.exit(exitCodeRef.value)
end

return main
