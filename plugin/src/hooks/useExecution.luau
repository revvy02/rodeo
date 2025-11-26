--[[
	useExecution - Custom hook for script execution management

	Handles script execution, log capture, and result reporting.
	Uses utils and reloader modules for actual execution logic.
]]

local React = require(script.Parent.Parent.Parent.packages.react)
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local utils = require(script.Parent.Parent.utils)
local reloader = require(script.Parent.Parent.reloader)

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
	script: string,
	executionId: string,
	instancePath: string?,
	logFilter: LogFilter?,
	cacheRequires: boolean?,
}

export type UseExecutionOptions = {
	sendMessage: (messageType: string, executionId: string, additionalData: { [string]: any }?) -> (),
	onExecutionComplete: (() -> ())?,
}

export type UseExecutionReturn = {
	executeScript: (params: ExecutionParams) -> (),
	isExecuting: boolean,
}

local function useExecution(options: UseExecutionOptions): UseExecutionReturn
	-- Execution state
	local isExecuting, setIsExecuting = React.useState(false)

	-- Refs for mutable values
	local currentExecutionIdRef = React.useRef(nil :: string?)
	local logConnectionRef = React.useRef(nil :: RBXScriptConnection?)

	-- Setup log capture
	local setupLogCapture = React.useCallback(function(executionId: string, logFilter: LogFilter?)
		if not logFilter or not logFilter.enableLogs then
			return
		end

		logConnectionRef.current = LogService.MessageOut:Connect(function(body, messageType)
			if currentExecutionIdRef.current ~= executionId then
				return
			end

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

			options.sendMessage("output", executionId, {
				level = level,
				body = body,
			})
		end)
	end, { options.sendMessage })

	-- Cleanup log connection
	local cleanupLogConnection = React.useCallback(function()
		if logConnectionRef.current then
			logConnectionRef.current:Disconnect()
			logConnectionRef.current = nil
		end
	end, {})

	-- Execute script function
	local executeScript = React.useCallback(function(params: ExecutionParams)
		local executionId = params.executionId
		local scriptContent = params.script
		local instancePath = params.instancePath
		local logFilter = params.logFilter or {
			enableWarn = true,
			enableError = true,
			enableInfo = true,
			enableOutput = true,
			enableLogs = true,
		}
		local cacheRequires = params.cacheRequires

		-- Set execution state
		currentExecutionIdRef.current = executionId
		setIsExecuting(true)

		-- Clear previous log connection
		cleanupLogConnection()

		-- Setup log capture with filter
		setupLogCapture(executionId, logFilter)

		-- Create the module script
		local moduleScript = utils.createModuleScript(scriptContent, instancePath)

		-- Setup uncachable require traversal (clones and renames modules)
		-- Skip if cacheRequires flag is set for better performance
		local cleanup = nil
		if not cacheRequires then
			cleanup = reloader.setupUncachableRequireModuleTraversal(moduleScript)
		end

		-- Execute the module
		local success, result = utils.executeModule(moduleScript)

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

		-- Send done message
		options.sendMessage("done", executionId, {
			result = serializedResult,
		})

		-- Wait for "done" message to flush through WebSocket buffers
		task.wait(0.1)

		-- Reset execution state
		currentExecutionIdRef.current = nil
		setIsExecuting(false)

		-- Cleanup log connection after execution
		cleanupLogConnection()

		-- Call completion callback
		if options.onExecutionComplete then
			options.onExecutionComplete()
		end
	end, { options.sendMessage, options.onExecutionComplete, setupLogCapture, cleanupLogConnection })

	-- Cleanup on unmount
	React.useEffect(function()
		return function()
			cleanupLogConnection()
		end
	end, { cleanupLogConnection })

	return {
		executeScript = executeScript,
		isExecuting = isExecuting,
	}
end

return useExecution
