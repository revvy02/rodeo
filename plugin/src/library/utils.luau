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
local module = script:WaitForChild("module")

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
]]

local function createExecutionContext(source: string, target: ExecutionTarget, executionId: string): ExecutionContext
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

	-- Create module with user source as child of runner
	local module = Instance.new("ModuleScript")
	module.Name = "module"
	module.Source = source
	module.Parent = runner

	-- Set runner source
	runner.Source = RUNNER_SOURCE

	local cleanup = function()
		runner:Destroy() -- Children (events, module) destroyed automatically
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
