local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local resultsEvent = script.results
local incomingEvent = script.incoming
local outgoingEvent = script.outgoing

-- Resolve dependencies via ObjectValue refs (all nil-parented for clean stack traces)
local refs = script.refs
local function ref(name: string): any
	return refs[name].Value
end

local module = ref("module")

-- Get execution params from attributes
local executionId = script:GetAttribute("executionId") or ""
local scriptArgs = HttpService:JSONDecode(script:GetAttribute("scriptArgs") or "[]")
local returnFile = script:GetAttribute("returnFile") or ""
local showReturn = script:GetAttribute("showReturn") or false
local outputFile = script:GetAttribute("outputFile") or ""
local logFilter = HttpService:JSONDecode(script:GetAttribute("logFilter") or "{}")

-- Wire up RPC using shared transport-agnostic module + BindableEvent transport
local createRpc = require(ref("rpc"))
local rpc = createRpc(function(msg)
	outgoingEvent:Fire(msg)
end)
incomingEvent.Event:Connect(function(msg)
	if msg.type == "rpc:response" and msg.id then
		rpc.handleResponse(msg)
	end
end)

-- Runtime proto module — required directly via ref (works across VM boundaries for run:server/client).
-- Also published to _G so the cloned rodeo-shared factories (stream/fs/process/io) can pick it up.
local runtime = require(ref("runtimeProto"))
_G.__rodeo_runtime_proto = runtime

-- Fetch host info once, share across factories
local hostInfo = rpc.call("process_get_info", runtime.ProcessGetInfoRequest.new({}))

-- Create RPC-backed API implementations via factories
local processApi = require(ref("process"))(rpc, scriptArgs, hostInfo)
local streamApi = require(ref("stream"))(rpc)
local fsApi = require(ref("fs"))(rpc)
local apis = {
	fs = fsApi,
	io = require(ref("io"))(rpc),
	process = processApi,
	stream = streamApi,
	roblox = require(ref("roblox"))(rpc, fsApi, streamApi),
}

-- Publish to _G so require("@rodeo/fs") etc. can find them
_G.__rodeo_procs = _G.__rodeo_procs or {}
_G.__rodeo_procs[executionId] = apis
_G.__rodeo_eid = executionId

local normalize = require(ref("normalize"))
local serializeToLuau = require(ref("serialize"))
local setupLogging = require(ref("logging"))

-- Setup log capture (LogService → stdout stream, optional output file)
local logConnection, outputFileStream = setupLogging(LogService, apis.fs, apis.stream, apis.io, logFilter, outputFile)

-- Execute user module
local target = script:GetAttribute("target") or "plugin"

local success, result = xpcall(function()
	if target == "elevated" then
		local TestService = game:GetService("TestService")
		local RunService = game:GetService("RunService")
		-- StudioMCP's execute_luau requires the datamodel_type its command bar
		-- should run in. This VM knows its own DataModel via RunService; map it
		-- to StudioMCP's enum (Edit / Server / Client). Without it the call is
		-- rejected with "datamodel_type is required".
		local datamodelType = if RunService:IsEdit()
			then "Edit"
			elseif RunService:IsClient() then "Client"
			else "Server"
		local refName = "RODEO_" .. executionId
		local ref = Instance.new("ObjectValue")
		ref.Name = refName
		ref.Value = module
		ref.Parent = TestService
		-- Wrapper xpcall's the require so StudioMCP's outer script frame ("AssistantCommand")
		-- never becomes part of the trace. On failure, return the trace as data with a sentinel
		-- prefix; the runner re-raises it below with level=0 so only inner frames surface.
		-- On success, JSON-encode the result inside the elevated wrapper so callers
		-- receive the original typed value (boolean, number, table, etc.) instead of
		-- StudioMCP's lossy string stringification. The runner decodes it back on
		-- receipt before normalize+wire-encode.
		local code = [[
			local HttpService = game:GetService("HttpService")
			local ref = game:GetService("TestService"):FindFirstChild("]] .. refName .. [[")
			local ok, result = xpcall(function()
				return require(ref.Value)
			end, function(err)
				return tostring(err) .. "\n" .. debug.traceback(nil, 2)
			end)
			if not ok then return "__RODEO_ELEVATED_ERROR__" .. tostring(result) end
			local jsonOk, jsonResult = pcall(HttpService.JSONEncode, HttpService, result)
			if jsonOk then return "__RODEO_ELEVATED_JSON__" .. jsonResult end
			return tostring(result) -- non-JSON-encodable (Instance, Vector3, etc.) → string fallback
		]]
		local r: runtime.McpCallResponse = rpc.call("mcp_call", runtime.McpCallRequest.new({
			tool = "execute_luau",
			argumentsJson = HttpService:JSONEncode({ code = code, datamodel_type = datamodelType }),
		}))
		ref:Destroy()
		if typeof(r.result) == "string" then
			if string.sub(r.result, 1, 24) == "__RODEO_ELEVATED_ERROR__" then
				error(string.sub(r.result, 25), 0)
			end
			if string.sub(r.result, 1, 23) == "__RODEO_ELEVATED_JSON__" then
				return HttpService:JSONDecode(string.sub(r.result, 24))
			end
		end
		return r.result
	end
	return require(module)
end, debug.traceback)

task.wait(0.2) -- Allow final logs to flush
logConnection:Disconnect()
if outputFileStream then
	apis.stream.close(outputFileStream)
end

-- Handle return value output. `returnValueJson` is the canonical wire-format
-- (JSON-encoded normalized result); it flows over the WS as
-- `ExecutionDone.return_value` only when no return file was given — a return
-- file captures the value instead, keeping it off the done message (a single
-- unchunkable hop whose downstream transports cap at a few MB). File and
-- stdout writes are size-unbounded: stream.write chunks large payloads.

local returnValueJson: string? = nil
if success and result ~= nil then
	local normalized = normalize(result)
	local isLuauReturnFile = returnFile ~= "" and string.match(returnFile, "%.luau?$") ~= nil

	-- The JSON form backs the wire field, --show-return, and non-.luau return
	-- files; .luau return files serialize to Luau source instead, so the
	-- (potentially huge) encode is skipped when nothing consumes it.
	local json: string? = nil
	if not isLuauReturnFile or showReturn then
		json = HttpService:JSONEncode(normalized)
	end

	if returnFile ~= "" then
		local f = apis.fs.open(returnFile, "w")
		apis.stream.write(f, if isLuauReturnFile then serializeToLuau(normalized) else json :: string)
		apis.stream.close(f)
	end

	if showReturn then
		apis.stream.write(apis.io.stdout, (json :: string) .. "\n")
	end

	if returnFile == "" then
		returnValueJson = json
	end
end

-- Clean up process-scoped _G entry
_G.__rodeo_eid = nil
_G.__rodeo_procs[executionId] = nil

resultsEvent:Fire({
	success = success,
	error = not success and tostring(result) or nil,
	returnValue = returnValueJson,
})

return nil
