-- Run command: Run script via persistent serve server

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local config = require("../library/config")
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

local function resolveScriptPath(scriptArg: string): string
	-- If it looks like a path (contains separator), use as-is
	if string.find(scriptArg, "/") or string.find(scriptArg, "\\") then
		return scriptArg
	end

	-- Try .rodeo directory
	local rodeoDir = ".rodeo"
	if fs.isDir(rodeoDir) then
		-- Try with .luau extension
		local withExt = `{rodeoDir}/{scriptArg}.luau`
		if fs.isFile(withExt) then
			return withExt
		end

		-- Try as-is (already has extension or no extension)
		local asIs = `{rodeoDir}/{scriptArg}`
		if fs.isFile(asIs) then
			return asIs
		end
	end

	-- Fall back to original (will error in validateConfig if not found)
	return scriptArg
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

	-- Match --!rodeo directive
	local directive = string.match(directiveLine, "^%-%-!rodeo%s+(.+)$")
	if not directive then
		return nil
	end

	-- Parse flags from directive string
	local result = {}

	-- Parse --key value pairs (e.g., --client 1, --context server)
	for key, value in string.gmatch(directive, "%-%-([%w-]+)%s+([^%-]%S*)") do
		local numValue = tonumber(value)
		result[key] = numValue or value
	end

	-- Parse standalone flags (like --cache-requires)
	-- Match flags at end of line
	local endFlag = string.match(directive, "%-%-([%w-]+)%s*$")
	if endFlag and not result[endFlag] then
		result[endFlag] = true
	end

	-- Match flags followed by another flag
	for flag in string.gmatch(directive, "%-%-([%w-]+)%s+%-%-") do
		if not result[flag] then
			result[flag] = true
		end
	end

	return result
end

local function applyDirective(args: any, directive: { [string]: any })
	for key, value in pairs(directive) do
		-- Convert kebab-case to snake_case for argparse compatibility
		local argKey = string.gsub(key, "-", "_")
		-- Only apply if CLI didn't specify this flag
		if args[argKey] == nil then
			args[argKey] = value
		end
	end
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
			scriptPath = resolveScriptPath(args.script)
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

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter, cacheRequires: boolean?, context: string)
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
			scriptPath = resolveScriptPath(args.script)
		end
	end

	-- Read script content early to parse directives
	local scriptContent = execution.readScriptContent(scriptPath, scriptSource)

	-- Parse and apply directives from script (CLI args override)
	local directive = parseDirective(scriptContent)
	if directive then
		applyDirective(args, directive)
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

	local ws = connectToServer(host, port)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath, cfg.filterBits, cfg.filterMask, cfg.logFilter, cfg.cacheRequires, cfg.context)

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
