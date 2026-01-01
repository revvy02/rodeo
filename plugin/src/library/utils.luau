-- Shared utilities for rodeo plugins

local function resolveInstancePath(path: string): Instance?
	local resolver = Instance.new("ModuleScript")
	resolver.Name = "__rodeo_path_resolver"
	resolver.Source = "return " .. path
	resolver.Parent = game:GetService("ReplicatedStorage")

	local success, result = pcall(function()
		return require(resolver)
	end)

	resolver:Destroy()

	if success and typeof(result) == "Instance" then
		return result
	end
	return nil
end

local function createModuleScript(script: string, instancePath: string?): (ModuleScript, () -> ())
	local moduleScript: ModuleScript
	local cleanup = function() end

	if instancePath then
		local originalInstance = resolveInstancePath(instancePath)
		if originalInstance and originalInstance:IsA("ModuleScript") then
			moduleScript = originalInstance:Clone()
			-- moduleScript.Source = script
			-- Rename original so clone takes precedence
			originalInstance.Name = originalInstance.Name .. ".rodeo.ignore"
			moduleScript.Parent = originalInstance.Parent

			cleanup = function()
				moduleScript:Destroy()
				originalInstance.Name = string.gsub(originalInstance.Name, "%.rodeo%.ignore$", "")
			end
		else
			if originalInstance then
				warn(`[rodeo] Instance at {instancePath} is not a ModuleScript, using temp module`)
			else
				warn(`[rodeo] Instance not found: {instancePath}, using temp module`)
			end
			moduleScript = Instance.new("ModuleScript")
			moduleScript.Source = script
			moduleScript.Parent = game:GetService("ReplicatedStorage")
			cleanup = function()
				moduleScript:Destroy()
			end
		end
	else
		moduleScript = Instance.new("ModuleScript")
		moduleScript.Source = script
		moduleScript.Parent = game:GetService("ReplicatedStorage")
		cleanup = function()
			moduleScript:Destroy()
		end
	end

	return moduleScript, cleanup
end

export type ExecutionTarget = "server" | "client" | "plugin"

export type ExecutionContext = {
	runner: Script | LocalScript | ModuleScript,
	module: ModuleScript,
	resultsEvent: BindableEvent,
	logsEvent: BindableEvent,
	cleanup: () -> (),
}

local RUNNER_SOURCE = [[
local LogService = game:GetService("LogService")
local HttpService = game:GetService("HttpService")

local resultsEvent = script:WaitForChild("results")
local logsEvent = script:WaitForChild("logs")
local moduleRef = script:WaitForChild("moduleRef")
local module = moduleRef.Value

-- Capture logs during execution
local logConnection
logConnection = LogService.MessageOut:Connect(function(body, messageType)
	local level = ({
		[Enum.MessageType.MessageOutput] = "Print",
		[Enum.MessageType.MessageInfo] = "Info",
		[Enum.MessageType.MessageWarning] = "Warning",
		[Enum.MessageType.MessageError] = "Error",
	})[messageType] or "Info"

	logsEvent:Fire({
		level = level,
		body = body,
	})
end)

local success, result = xpcall(function()
	return require(module)
end, debug.traceback)

task.wait(0.1) -- Allow final logs to flush
logConnection:Disconnect()

-- Serialize result
local serializedResult = nil
if success and result ~= nil then
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(result)
	end)
	serializedResult = ok and encoded or tostring(result)
end

resultsEvent:Fire({
	success = success,
	result = serializedResult,
	error = not success and tostring(result) or nil,
})

return nil
]]

local function createExecutionContext(source: string, target: ExecutionTarget, executionId: string, instancePath: string?, scriptPath: string?): ExecutionContext
	-- Create runner script for the target context
	local runner: Script | LocalScript | ModuleScript
	if target == "server" then
		runner = Instance.new("Script")
	elseif target == "client" then
		runner = Instance.new("LocalScript")
	else -- plugin
		runner = Instance.new("ModuleScript")
	end
	runner.Name = "__rodeo_runner_" .. executionId

	-- Create BindableEvents as children of runner
	local resultsEvent = Instance.new("BindableEvent")
	resultsEvent.Name = "results"
	resultsEvent.Parent = runner

	local logsEvent = Instance.new("BindableEvent")
	logsEvent.Name = "logs"
	logsEvent.Parent = runner

	-- Determine module name for stack traces
	-- The module name appears in error messages: Script 'NAME', Line X
	--
	-- Priority:
	-- 1. instancePath → use instance name (e.g. "MyModule")
	--    When running a file that maps to a Roblox instance, show the familiar instance name
	-- 2. scriptPath → use relative file path (e.g. ".rodeo/test.luau")
	--    When running a file not in sourcemap, show the file path for easy navigation
	-- 3. source → use the source code itself (e.g. "print('hello')")
	--    When running inline code via --source/stdin, emulate Roblox command bar behavior
	--    which shows the actual code in the error: Script 'for i = 1, 20 do error("ok") end', Line 1
	local moduleName = source
	if instancePath then
		local lastSegment = string.match(instancePath, '%["([^"]+)"%]$')
		if lastSegment then
			moduleName = lastSegment
		end
	elseif scriptPath then
		moduleName = scriptPath
	end

	-- Create or clone module
	local module: ModuleScript
	local originalInstance: ModuleScript? = nil
	if instancePath then
		local resolved = resolveInstancePath(instancePath)
		if resolved and resolved:IsA("ModuleScript") then
			originalInstance = resolved
			module = originalInstance:Clone()
			-- Rename original so clone takes precedence (like createModuleScript does)
			originalInstance.Name = originalInstance.Name .. ".rodeo.ignore"
			module.Parent = originalInstance.Parent
		else
			module = Instance.new("ModuleScript")
			module.Name = moduleName
			module.Source = source
		end
	else
		module = Instance.new("ModuleScript")
		module.Name = moduleName
		module.Source = source
	end

	-- Reference module via ObjectValue
	local moduleRef = Instance.new("ObjectValue")
	moduleRef.Name = "moduleRef"
	moduleRef.Value = module
	moduleRef.Parent = runner

	-- Set runner source
	runner.Source = RUNNER_SOURCE

	local cleanup = function()
		module:Destroy()
		if originalInstance then
			originalInstance.Name = string.gsub(originalInstance.Name, "%.rodeo%.ignore$", "")
		end
		runner:Destroy()
	end

	return {
		runner = runner,
		module = module,
		resultsEvent = resultsEvent,
		logsEvent = logsEvent,
		cleanup = cleanup,
	}
end

return {
	resolveInstancePath = resolveInstancePath,
	createModuleScript = createModuleScript,
	createExecutionContext = createExecutionContext,
}
