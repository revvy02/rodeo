--[[
	MessageHandler.luau - WebSocket message handling for the Rodeo plugin

	Handles incoming messages from the CLI server: exec, kill, rpc:response, welcome.
	Tracks active processes and manages execution lifecycle.
]]

local HttpService = game:GetService("HttpService")

local runtime = require(script.Parent.Parent.Parent.library.runtime)
local utils = require(script.Parent.Parent.Parent.library.utils)
local flags = require(script.Parent.Parent.Parent.library.flags)
local mode_driver = require(script.Parent.Parent.Parent.library.mode_driver)
local rodeoProto = require(script.Parent.Parent.Parent.Parent.proto.rodeo)
local runtimeProto = require(script.Parent.Parent.Parent.Parent.proto.runtime)

export type ProcessEntry = {
	name: string,
	state: "running" | "done" | "error" | "killed",
}

type CreateHandlerArgs = {
	client: any,
	verbose: boolean,
	setIsExecuting: (boolean) -> (),
	setActiveProcesses: ({ [string]: ProcessEntry }) -> (),
}

local function createHandler(args: CreateHandlerArgs): () -> ()
	local client = args.client
	local verbose = args.verbose
	local setIsExecuting = args.setIsExecuting
	local setActiveProcesses = args.setActiveProcesses

	-- Track active processes keyed by executionId
	local activeProcesses: { [string]: { ctx: utils.ExecutionContext, kill: (() -> ())? } } = {}

	-- UI-facing process entries
	local processEntries: { [string]: ProcessEntry } = {}

	local connection = client.MessageReceived:Connect(function(message: string)
		local success, decoded = pcall(function()
			return HttpService:JSONDecode(message)
		end)

		if not success then
			if verbose then
				warn("[rodeo] Failed to decode message:", message)
			end
			return
		end

		-- Parse as ServerMessage proto (oneof field presence determines type)
		local serverMsg = rodeoProto.ServerMessage.jsonDecode(decoded)

		if serverMsg.msg and serverMsg.msg.type == "welcome" then
			local welcome = serverMsg.msg.value
			if welcome.version and welcome.version ~= flags.VERSION then
				warn(`[rodeo] Version mismatch: plugin is v{flags.VERSION}, server is v{welcome.version}`)
			end
		elseif serverMsg.msg and serverMsg.msg.type == "run" then
			local run = serverMsg.msg.value
			setIsExecuting(true)

			local target = run.target or "plugin"
			local lf = run.logFilter
			local logFilter = {
				enableWarn = lf and lf.enableWarn,
				enableError = lf and lf.enableError,
				enableInfo = lf and lf.enableInfo,
				enableOutput = lf and lf.enableOutput,
				enableLogs = lf and lf.enableLogs,
			}
			local scriptArgs = run.scriptArgs or {}
			local executionId = run.executionId

			local ctx = utils.createExecutionContext(
				run.script,
				target,
				executionId,
				run.instancePath,
				run.scriptPath
			)

			local killFn = runtime.executeInContext(ctx, target, {
				executionId = executionId,
				logFilter = logFilter,
				cacheRequires = run.cacheRequires,
				verbose = run.verbose or verbose,
				scriptArgs = scriptArgs,
				returnFile = run.returnFile,
				showReturn = run.showReturn,
				outputFile = run.outputFile,
				profile = run.profile,
			}, {
				onComplete = function(result)
					local msg = rodeoProto.PluginMessage.new({
						msg = { type = "done", value = rodeoProto.ExecutionDone.new({
							executionId = executionId,
							success = result and result.success or false,
							error = result and result.error,
						}) },
					})
					client:Send(HttpService:JSONEncode(msg:jsonEncode()))
					activeProcesses[executionId] = nil
					processEntries[executionId] = nil
					setActiveProcesses(table.clone(processEntries))
					-- Update executing state: still executing if any processes remain
					local hasActive = false
					for _ in pairs(activeProcesses) do
						hasActive = true
						break
					end
					if not hasActive then
						setIsExecuting(false)
					end
				end,
				onRpc = function(msg)
					-- msg.callJson is canonical ClientRpcCall JSON minus executionId.
					-- Stamp executionId, decode to typed, wrap, encode to wire.
					msg.callJson.executionId = executionId
					local typedCall = runtimeProto.ClientRpcCall.jsonDecode(msg.callJson)
					local rpcMsg = rodeoProto.PluginMessage.new({
						msg = { type = "rpc", value = typedCall },
					})
					client:Send(HttpService:JSONEncode(rpcMsg:jsonEncode()))
				end,
			})

			activeProcesses[executionId] = { ctx = ctx, kill = killFn }
			processEntries[executionId] = {
				name = run.scriptPath or "inline",
				state = "running",
			}
			setActiveProcesses(table.clone(processEntries))
		elseif serverMsg.msg and serverMsg.msg.type == "kill" then
			local kill = serverMsg.msg.value
			local proc = activeProcesses[kill.executionId]
			if proc and proc.kill then
				proc.kill()
				local killedMsg = rodeoProto.PluginMessage.new({
					msg = { type = "killed", value = rodeoProto.ExecutionKilled.new({
						executionId = kill.executionId,
					}) },
				})
				client:Send(HttpService:JSONEncode(killedMsg:jsonEncode()))
				activeProcesses[kill.executionId] = nil
				processEntries[kill.executionId] = nil
				setActiveProcesses(table.clone(processEntries))
				local hasActive = false
				for _ in pairs(activeProcesses) do
					hasActive = true
					break
				end
				if not hasActive then
					setIsExecuting(false)
				end
			end
		elseif serverMsg.msg and serverMsg.msg.type == "rpcResponse" then
			local rpcResp = serverMsg.msg.value  -- ClientRpcResponse
			-- Forward typed response to the runner. rpcResp.res is the tagged oneof variant:
			--   { type = "<method>", value = <Response> } | { type = "error", value = <string> }
			local proc = activeProcesses[rpcResp.executionId]
			if proc then
				proc.ctx.incomingEvent:Fire({
					type = "rpc:response",
					id = rpcResp.id,
					res = rpcResp.res,
				})
			end
		elseif serverMsg.msg and serverMsg.msg.type == "setTargetMode" then
			mode_driver.setTarget(serverMsg.msg.value.targetMode)
		end
	end)

	return function()
		connection:Disconnect()
	end
end

return {
	createHandler = createHandler,
}
