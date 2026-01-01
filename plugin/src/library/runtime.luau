--[[
	runtime.luau - Script execution runtime

	Encapsulates all script execution logic including:
	- Module reloading (uncachable requires)
	- Log capture and filtering
	- Result serialization
	- Cleanup
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local terminal = require(script.Parent.terminal)
local utils = require(script.Parent.utils)

local LOG_TYPE_TO_LEVEL = {
	[Enum.MessageType.MessageOutput] = "Print",
	[Enum.MessageType.MessageInfo] = "Info",
	[Enum.MessageType.MessageWarning] = "Warning",
	[Enum.MessageType.MessageError] = "Error",
}

export type LogFilter = {
	enableWarn: boolean?,
	enableError: boolean?,
	enableInfo: boolean?,
	enableOutput: boolean?,
	enableLogs: boolean?,
}

export type ExecutionParams = {
	executionId: string,
	logFilter: LogFilter?,
	cacheRequires: boolean?,
	verbose: boolean?,
}

export type ExecutionCallbacks = {
	onOutput: (level: string, body: string) -> (),
	onComplete: (result: string?) -> (),
}

-- Get absolute instance path from game using bracket notation
-- e.g. game["Workspace"]["Part"] or game["ReplicatedStorage"]["Modules"]["Utils"]
-- Returns nil if the instance is not a descendant of game
local function getAbsoluteInstancePath(instance: Instance): string?
	if instance == game then
		return "game"
	end

	local parts = {}
	local current = instance

	while current and current ~= game do
		table.insert(parts, 1, `["{current.Name}"]`)
		current = current.Parent
	end

	-- If we didn't reach game, the instance has no valid path
	if current ~= game then
		return nil
	end

	return "game" .. table.concat(parts, "")
end

-- Debug logging (verbose flag passed per-execution)
local VERBOSE = false

local function log(message: string)
	if VERBOSE then
		local source, line, name = debug.info(2, "sln")
		local formattedSource = terminal.style.gray(source)
		local formattedLine = terminal.style.red(tostring(line))
		local formattedName = terminal.style.green(name or "?")
		print(`[{formattedSource}:{formattedLine} {formattedName}] {message}`)
	end
end

-- Extract content from outermost parentheses, handling nested parens
-- Returns: content string and ending position, or nil if not found
local function extractParenthesisContent(str: string, startPos: number): (string?, number?)
	local openParenPos = string.find(str, "%(", startPos)
	if not openParenPos then
		return nil, nil
	end

	local depth = 0
	local pathStart = openParenPos + 1
	local pathEnd = nil

	for i = openParenPos, #str do
		local char = string.sub(str, i, i)
		if char == "(" then
			depth = depth + 1
		elseif char == ")" then
			depth = depth - 1
			if depth == 0 then
				pathEnd = i - 1
				return string.sub(str, pathStart, pathEnd), i
			end
		end
	end

	return nil, nil
end

-- Extract all require() calls from source code
local function extractRequires(source: string): { string }
	local requires = {}
	local pos = 1

	while true do
		-- Find next "require" keyword
		local requireStart = string.find(source, "require%s*%(", pos)
		if not requireStart then
			break
		end

		-- Check if this require is commented out (-- before require on same line)
		-- Find the start of the current line by searching backwards for newline
		local lineStart = 1
		for i = requireStart - 1, 1, -1 do
			if string.sub(source, i, i) == "\n" then
				lineStart = i + 1
				break
			end
		end
		local lineBeforeRequire = string.sub(source, lineStart, requireStart - 1)
		if string.find(lineBeforeRequire, "%-%-") then
			-- This require is in a comment, skip it
			pos = requireStart + 1
			continue
		end

		-- Extract the full require call with nested parentheses
		local content, endPos = extractParenthesisContent(source, requireStart)
		if content and endPos then
			-- Reconstruct the full require string
			local fullRequire = string.sub(source, requireStart, endPos)
			table.insert(requires, fullRequire)
			pos = endPos + 1
		else
			-- Skip this occurrence and continue
			pos = requireStart + 1
		end
	end

	return requires
end

-- Convert Roblox string path to instance
-- Handles @self, ./, ../
local function getRobloxStringPathInstance(rootInstance: Instance, pathString: string): ModuleScript?
	local current = rootInstance

	-- Remove quotes if present
	pathString = string.gsub(pathString, "^[\"']", "")
	pathString = string.gsub(pathString, "[\"']$", "")

	-- Handle @self prefix (means the script itself)
	if string.sub(pathString, 1, 5) == "@self" then
		current = rootInstance
		pathString = string.sub(pathString, 6) -- Remove "@self"
		if string.sub(pathString, 1, 1) == "/" then
			pathString = string.sub(pathString, 2) -- Remove leading /
		end
	else
		-- Require explicit ./ or ../ prefix (Luau spec compliance)
		-- ./ means script.Parent (sibling)
		-- ../ means go up one level (chainable)

		-- Start from script.Parent for relative paths
		current = rootInstance.Parent or rootInstance

		-- Must have ./ or ../ prefix
		if string.sub(pathString, 1, 2) == "./" then
			pathString = string.sub(pathString, 3) -- Remove "./"
		elseif string.sub(pathString, 1, 3) == "../" then
			-- Handle chained ../
			while string.sub(pathString, 1, 3) == "../" do
				current = current.Parent or current
				pathString = string.sub(pathString, 4) -- Remove "../"
			end
		else
			-- No valid prefix (./, ../, or @) - return nil per Luau spec
			return nil
		end
	end

	-- If path is now empty, return current
	if pathString == "" then
		if typeof(current) == "Instance" and current:IsA("ModuleScript") then
			return current
		end
		return nil
	end

	-- Split remaining path by / and navigate
	local parts = string.split(pathString, "/")
	for _, part in parts do
		if part ~= "" then
			local child = current:FindFirstChild(part)
			if not child then
				return nil
			end
			current = child
		end
	end

	-- Verify final result is a ModuleScript
	if typeof(current) == "Instance" and current:IsA("ModuleScript") then
		return current
	end

	return nil
end

-- Resolve a require path to an actual instance
-- Two-phase resolution: try loadstring first, then string path conversion
local function getRequireInstance(requireString: string, currentScript: Instance): ModuleScript?
	log(`Resolving require: {requireString} from {currentScript:GetFullName()}`)

	-- Extract the path from require(path) using helper function
	local pathExpr, _ = extractParenthesisContent(requireString, 1)
	if not pathExpr then
		log(`Failed to extract path from require string`)
		return nil
	end

	-- Strip quotes and whitespace from the path expression
	pathExpr = string.gsub(pathExpr, "^%s*[\"']?", "") -- Remove leading whitespace and quotes
	pathExpr = string.gsub(pathExpr, "[\"']?%s*$", "") -- Remove trailing quotes and whitespace

	-- Phase 1: Evaluate path using temp module (avoids loadstring/setfenv VM de-optimization)
	local success, result = pcall(function()
		local tempModule = Instance.new("ModuleScript")
		tempModule.Name = "__rodeo_resolver"
		-- Assign script to currentScript so child paths like script.SomeChild work
		tempModule.Source = 'script = script.Parent["' .. currentScript.Name .. '"]\nreturn ' .. pathExpr
		tempModule.Parent = currentScript.Parent
		local resolved = require(tempModule)
		tempModule:Destroy()
		return resolved
	end)

	-- If temp module succeeded and returned a ModuleScript, use it
	if success and typeof(result) == "Instance" and result:IsA("ModuleScript") then
		log(`Phase 1 (temp module): Resolved to {result:GetFullName()}`)
		return result
	end

	-- Phase 2: If loadstring failed or didn't return an instance, try string path conversion
	-- This handles "@self/path", "./relative", etc.
	log(`Phase 1 failed, trying Phase 2 (string conversion)`)
	local resolved = getRobloxStringPathInstance(currentScript, pathExpr)
	if resolved then
		log(`Phase 2: Resolved to {resolved:GetFullName()}`)
	else
		log(`Phase 2: Failed to resolve`)
	end
	return resolved
end

local function recurse(rootModule: ModuleScript, clonedModules: { [ModuleScript]: true }, disabledInstances)
	log(`Processing module: {rootModule:GetFullName()}`)
	local source = rootModule.Source
	local requires = extractRequires(source)
	log(`Found {#requires} require() calls`)

	-- extract require calls
	-- for each require, convert path to instance
	for _, requirePath in requires do
		local requireModule = getRequireInstance(requirePath, rootModule)

		if not requireModule then
			log(`Failed to resolve require, skipping`)
			continue
		end

		if clonedModules[requireModule] then
			log(`Skipping {requireModule:GetFullName()} (already cloned)`)
			continue
		end

		local requireModuleCopy = requireModule:Clone()
		clonedModules[requireModuleCopy] = true
		log(`Cloned: {requireModule:GetFullName()}`)

		-- Track all descendants of the original module
		local descendantCount = 0
		for _, descendant in requireModuleCopy:GetDescendants() do
			if descendant:IsA("ModuleScript") then
				clonedModules[descendant] = true
				descendantCount = descendantCount + 1
			end
		end
		if descendantCount > 0 then
			log(`Tracked {descendantCount} descendant modules`)
		end

		local name = requireModule.Name
		requireModule.Name = name .. ".rodeo.ignore"
		requireModuleCopy.Parent = requireModule.Parent
		log(`Swapped: {name} <-> {requireModule.Name}`)

		table.insert(disabledInstances, requireModule)

		recurse(requireModuleCopy, clonedModules, disabledInstances)
	end
end

-- Setup uncachable requires by cloning and renaming modules
local function setupUncachableRequireModuleTraversal(rootInstance: ModuleScript): () -> ()
	log(`Starting uncachable require setup for {rootInstance:GetFullName()}`)

	-- parse rootInstance Source
	local clonedModules = {}
	local disabledInstances = {}
	recurse(rootInstance, clonedModules, disabledInstances)

	-- Count cloned modules
	local cloneCount = 0
	for _ in clonedModules do
		cloneCount = cloneCount + 1
	end

	log(`Setup complete: {cloneCount} modules tracked, {#disabledInstances} originals renamed`)

	return function()
		log(`Starting cleanup`)

		local restoredCount = 0
		for _, instance in disabledInstances do
			instance.Name = string.gsub(instance.Name, "%.rodeo%.ignore$", "")
			restoredCount = restoredCount + 1
		end
		log(`Restored {restoredCount} original module names`)

		local destroyedCount = 0
		for module in clonedModules do
			module:Destroy()
			destroyedCount = destroyedCount + 1
		end
		log(`Destroyed {destroyedCount} cloned modules`)
		log(`Cleanup complete`)
	end
end

-- Execute module and handle errors
local function executeModule(moduleScript: ModuleScript): (boolean, any)
	local success, result = xpcall(function()
		return require(moduleScript)
	end, debug.traceback)

	if not success then
		local event = Instance.new("BindableEvent")
		event.Event:Connect(function()
			error(result, 0)
		end)
		event:Fire()
		return false, nil
	end

	return true, result
end

-- Main execute function
local function execute(moduleScript: ModuleScript, params: ExecutionParams, callbacks: ExecutionCallbacks)
	-- Set verbose flag for this execution
	VERBOSE = params.verbose or false

	local logConnection: RBXScriptConnection? = nil
	local logFilter = params.logFilter or {
		enableWarn = true,
		enableError = true,
		enableInfo = true,
		enableOutput = true,
		enableLogs = true,
	}

	-- Setup log capture
	if logFilter.enableLogs then
		logConnection = LogService.MessageOut:Connect(function(body, messageType)
			local level = LOG_TYPE_TO_LEVEL[messageType] or "Info"

			-- Filter based on log level
			if level == "Warning" and not logFilter.enableWarn then
				return
			elseif level == "Error" and not logFilter.enableError then
				return
			elseif level == "Info" and not logFilter.enableInfo then
				return
			elseif level == "Print" and not logFilter.enableOutput then
				return
			end

			callbacks.onOutput(level, body)
		end)
	end

	-- Resolve path BEFORE setting up traversal so we get the correct module
	local modulePath = getAbsoluteInstancePath(moduleScript)
	log(`Resolved path = {modulePath}`)

	-- Setup uncachable requires
	local cleanup: (() -> ())? = nil
	if not params.cacheRequires then
		cleanup = setupUncachableRequireModuleTraversal(moduleScript)
	end

	-- Resolve module via path (picks up cloned module if traversal is activ and the root got cloned)
	if modulePath then
		local resolver = Instance.new("ModuleScript")
		resolver.Name = "__rodeo_path_resolver"
		resolver.Source = "return " .. modulePath
		resolver.Parent = game:GetService("ReplicatedStorage")
		moduleScript = require(resolver)
		resolver:Destroy()
		log(`Target module: {moduleScript:GetFullName()}`)
	end

	-- Execute the module
	local success, result = executeModule(moduleScript)

	-- Wait for logs to be captured and sent
	task.wait(0.1)

	-- Cleanup: restore original names and destroy clones
	if cleanup then
		cleanup()
	end

	-- Serialize result
	local serializedResult = nil
	if success and result ~= nil then
		local serializeSuccess, encoded = pcall(function()
			return HttpService:JSONEncode(result)
		end)
		if serializeSuccess then
			serializedResult = encoded
		else
			-- Fallback to tostring for non-serializable types
			serializedResult = tostring(result)
		end
	end

	-- Wait for "done" message to flush through WebSocket buffers
	task.wait(0.1)

	-- Cleanup log connection
	if logConnection then
		logConnection:Disconnect()
	end

	-- Call completion callback
	callbacks.onComplete(serializedResult)
end

type ExecutionTarget = "server" | "client" | "plugin"

-- Execute a module in a specific context (server/client/plugin)
-- ctx contains the runner, module, events, and cleanup function (created by utils.createExecutionContext)
local function executeInContext(
	ctx: utils.ExecutionContext,
	target: ExecutionTarget,
	params: ExecutionParams,
	callbacks: ExecutionCallbacks
)
	-- Set verbose flag for this execution
	VERBOSE = params.verbose or false

	-- Setup uncacheable require traversal (from plugin context, before execution)
	local traversalCleanup: (() -> ())? = nil
	if not params.cacheRequires then
		traversalCleanup = setupUncachableRequireModuleTraversal(ctx.module)
	end

	-- Listen for logs
	local logsConnection = ctx.logsEvent.Event:Connect(function(logData)
		local level = logData.level
		local body = logData.body
		local logFilter = params.logFilter or {}

		-- Apply log filter
		if level == "Warning" and logFilter.enableWarn == false then
			return
		elseif level == "Error" and logFilter.enableError == false then
			return
		elseif level == "Info" and logFilter.enableInfo == false then
			return
		elseif level == "Print" and logFilter.enableOutput == false then
			return
		end

		callbacks.onOutput(level, body)
	end)

	-- Listen for results
	local resultsConnection
	resultsConnection = ctx.resultsEvent.Event:Connect(function(result)
		resultsConnection:Disconnect()
		logsConnection:Disconnect()

		if not result.success then
			callbacks.onOutput("Error", result.error)
		end

		-- Cleanup traversal first, then destroy runner
		if traversalCleanup then
			traversalCleanup()
		end
		ctx.cleanup()

		callbacks.onComplete(result.result)
	end)

	-- Parent runner to trigger execution (or require for plugin)
	if target == "server" then
		ctx.runner.Parent = ServerScriptService
	elseif target == "client" then
		local player = Players.LocalPlayer
		if player then
			ctx.runner.Parent = player:WaitForChild("PlayerScripts")
		else
			-- No LocalPlayer - can't execute in client context
			resultsConnection:Disconnect()
			logsConnection:Disconnect()
			if traversalCleanup then
				traversalCleanup()
			end
			ctx.cleanup()
			callbacks.onOutput("Error", "Cannot execute in client context: no LocalPlayer")
			callbacks.onComplete(nil)
			return
		end
	else -- plugin
		ctx.runner.Parent = ReplicatedStorage
		task.spawn(function()
			require(ctx.runner)
		end)
	end
end

return {
	execute = execute,
	executeInContext = executeInContext,
	executeModule = executeModule,
	setupUncachableRequireModuleTraversal = setupUncachableRequireModuleTraversal,
	extractRequires = extractRequires,
	extractParenthesisContent = extractParenthesisContent,
	getRobloxStringPathInstance = getRobloxStringPathInstance,
	getRequireInstance = getRequireInstance,
}
