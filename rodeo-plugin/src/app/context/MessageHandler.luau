--[[
	MessageHandler.luau - WebSocket message handling for the Rodeo plugin

	Handles incoming messages from the CLI server: exec, kill, rpc:response, welcome.
	Tracks active processes and manages execution lifecycle.
]]

local HttpService = game:GetService("HttpService")

local runtime = require(script.Parent.Parent.Parent.library.runtime)
local utils = require(script.Parent.Parent.Parent.library.utils)
local constants = require(script.Parent.Parent.Parent.library.constants)
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

	-- Runs whose script arrived flagged `scriptContinues`: the RunCommand
	-- carried only the first piece, ScriptChunk messages carry the rest in
	-- order. Keyed by executionId; executed once the last chunk lands.
	local pendingRuns: { [string]: { run: any, parts: { string } } } = {}

	-- Start a run whose full script is assembled. Everything after script
	-- transport is unchanged from the pre-chunking single-message path.
	local function executeRun(run)
		setIsExecuting(true)

		local context = run.context or "plugin"
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
			context,
			executionId,
			run.instancePath,
			run.scriptPath
		)

		local killFn = runtime.executeInContext(ctx, context, {
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
						returnValue = result and result.returnValue,
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
				--
				-- This runs on the outgoing-event thread, NOT the thread blocked
				-- in rpc.call's event:Wait(). If encoding/sending throws here
				-- (e.g. JSONEncode rejects a string field carrying non-UTF-8
				-- bytes — the wire is a UTF-8-locked WebSocket text frame), the
				-- error would otherwise be swallowed and the caller would hang
				-- forever. Catch it and deliver an error response for this id so
				-- rpc.call's event:Wait() returns and errors at the call site.
				msg.callJson.executionId = executionId
				local ok, err = pcall(function()
					local typedCall = runtimeProto.ClientRpcCall.jsonDecode(msg.callJson)
					local rpcMsg = rodeoProto.PluginMessage.new({
						msg = { type = "rpc", value = typedCall },
					})
					client:Send(HttpService:JSONEncode(rpcMsg:jsonEncode()))
				end)
				if not ok then
					-- Defer the error response. onRpc runs synchronously inside
					-- rpc.call's send() (BindableEvent:Fire is synchronous), so a
					-- direct Fire here would land before rpc.call reaches
					-- event:Wait() and be missed, hanging the caller forever.
					-- task.defer resumes after the caller is parked on Wait().
					local errValue = tostring(err)
					local id = msg.callJson.id
					task.defer(function()
						ctx.incomingEvent:Fire({
							type = "rpc:response",
							id = id,
							res = { type = "error", value = errValue },
						})
					end)
				end
			end,
		})

		activeProcesses[executionId] = { ctx = ctx, kill = killFn }
		processEntries[executionId] = {
			name = run.scriptPath or "inline",
			state = "running",
		}
		setActiveProcesses(table.clone(processEntries))
	end

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
			if welcome.version and welcome.version ~= constants.VERSION then
				warn(`[rodeo] Version mismatch: plugin is v{constants.VERSION}, server is v{welcome.version}`)
			end
		elseif serverMsg.msg and serverMsg.msg.type == "run" then
			local run = serverMsg.msg.value
			if run.scriptContinues then
				-- First piece of a chunked script — stash and wait for the
				-- ScriptChunk sequence before executing.
				pendingRuns[run.executionId] = { run = run, parts = { run.script } }
				return
			end
			executeRun(run)
		elseif serverMsg.msg and serverMsg.msg.type == "scriptChunk" then
			local chunk = serverMsg.msg.value
			local pending = pendingRuns[chunk.executionId]
			if not pending then
				warn(`rodeo: script chunk for unknown execution {chunk.executionId} — dropping`)
				return
			end
			table.insert(pending.parts, chunk.data)
			if chunk.isLast then
				pendingRuns[chunk.executionId] = nil
				pending.run.script = table.concat(pending.parts)
				pending.run.scriptContinues = nil
				executeRun(pending.run)
			end
		elseif serverMsg.msg and serverMsg.msg.type == "kill" then
			local kill = serverMsg.msg.value
			-- A kill can land while the script is still streaming in — drop the
			-- partial assembly so the run never starts.
			pendingRuns[kill.executionId] = nil
			local proc = activeProcesses[kill.executionId]
			if proc and proc.kill then
				proc.kill()
			else
				-- Unknown execution (already completed, or lost to a plugin
				-- reload). Still ack below: kill is idempotent, and a silent
				-- drop leaves the master's run entry alive forever — rodeo
				-- kill would report success while the run stays in state.
				warn(`rodeo: kill for unknown execution {kill.executionId} — acking anyway`)
			end
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
