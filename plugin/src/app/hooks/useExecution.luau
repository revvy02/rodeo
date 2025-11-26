--[[
	useExecution - Custom hook for script execution management

	Thin wrapper around runtime module that provides React state management.
]]

local React = require("@pkg/react")
local runtime = require(script.Parent.Parent.Parent.runtime)
local utils = require(script.Parent.Parent.Parent.utils)

export type LogFilter = runtime.LogFilter

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
	verbose: boolean?,
}

export type UseExecutionReturn = {
	executeScript: (params: ExecutionParams) -> (),
	isExecuting: boolean,
}

local function useExecution(options: UseExecutionOptions): UseExecutionReturn
	local isExecuting, setIsExecuting = React.useState(false)

	local executeScript = React.useCallback(function(params: ExecutionParams)
		setIsExecuting(true)

		-- Create module from script string
		local moduleScript = utils.createModuleScript(params.script, params.instancePath)

		-- Execute via runtime
		runtime.execute(moduleScript, {
			executionId = params.executionId,
			logFilter = params.logFilter,
			cacheRequires = params.cacheRequires,
			verbose = options.verbose,
		}, {
			onOutput = function(level, body)
				options.sendMessage("output", params.executionId, {
					level = level,
					body = body,
				})
			end,
			onComplete = function(result)
				options.sendMessage("done", params.executionId, {
					result = result,
				})
				setIsExecuting(false)
				if options.onExecutionComplete then
					options.onExecutionComplete()
				end
			end,
		})
	end, { options.sendMessage, options.onExecutionComplete })

	return {
		executeScript = executeScript,
		isExecuting = isExecuting,
	}
end

return useExecution
