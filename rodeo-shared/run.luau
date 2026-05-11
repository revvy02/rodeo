-- Shared execution core for the rodeo plugin runner.
-- Handles the full execution lifecycle: APIs, logging, execution, return values, cleanup
--
-- Usage:
--   local run = require("rodeo-shared/run")
--   local success, result = run(rpc, params, function(apis)
--       return xpcall(function() return <execute user code> end, debug.traceback)
--   end)

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")

local createFs = require("./fs")
local createStream = require("./stream")
local createIo = require("./io")
local createProcess = require("./process")
local normalize = require("./normalize")
local serializeToLuau = require("./serialize")
local createLogging = require("./logging")

local ANSI = {
	error = "\27[1m\27[38;2;200;0;0m",
	reset = "\27[0m",
}

type RunParams = {
	executionId: string,
	scriptArgs: { string }?,
	showReturn: boolean?,
	returnFile: string?,
	outputFile: string?,
	logFilter: any?,
}

type Rpc = {
	call: (method: string, params: any) -> any,
	notify: (method: string, params: any) -> (),
}

--[=[
	Run an execution with the full rodeo lifecycle.

	@param rpc — bound RPC interface {call, notify}
	@param params — execution params
	@param execute — function(apis) -> (success: boolean, result: any)
	@return success, result
]=]
local function run(rpc: Rpc, params: RunParams, execute: (apis: any) -> (boolean, any)): (boolean, any)
	local executionId = params.executionId

	-- 1. Fetch host info
	local runtime = _G.__rodeo_runtime_proto
	local hostInfo = rpc.call("process_get_info", runtime.ProcessGetInfoRequest.new({}))

	-- 2. Build API factories
	local apis = {
		fs = createFs(rpc),
		stream = createStream(rpc),
		io = createIo(rpc),
		process = createProcess(rpc, params.scriptArgs or {}, hostInfo),
	}

	-- 3. Register in _G so require("@rodeo/fs") etc. works
	_G.__rodeo_procs = _G.__rodeo_procs or {}
	_G.__rodeo_procs[executionId] = apis
	_G.__rodeo_eid = executionId

	-- 4. Setup logging via LogService
	local logConnection, outputFileHandle = createLogging(
		LogService, apis.fs, apis.stream, apis.io,
		params.logFilter or {}, params.outputFile or ""
	)

	-- 5. Execute (caller-provided)
	local success, result = execute(apis)

	-- 6. Disconnect logging (before writing return value to avoid capturing it)
	task.wait(0.05)
	logConnection:Disconnect()
	if outputFileHandle then
		apis.stream.close(outputFileHandle)
	end

	-- 7. Handle return value
	if success and result ~= nil then
		local normalized = normalize(result)

		if params.returnFile and params.returnFile ~= "" then
			local f = apis.fs.open(params.returnFile, "w")
			if string.match(params.returnFile, "%.luau?$") then
				apis.stream.write(f, serializeToLuau(normalized))
			else
				apis.stream.write(f, HttpService:JSONEncode(normalized))
			end
			apis.stream.close(f)
		end

		if params.showReturn then
			apis.stream.write(apis.io.stdout, HttpService:JSONEncode(normalized) .. "\n")
		end
	end

	-- 8. Handle errors — write to stderr
	if not success then
		apis.stream.write(apis.io.stderr, ANSI.error .. tostring(result) .. ANSI.reset .. "\n")
	end

	-- 9. Clean up _G
	if _G.__rodeo_procs then
		_G.__rodeo_procs[executionId] = nil
	end
	if _G.__rodeo_eid == executionId then
		_G.__rodeo_eid = nil
	end

	return success, result
end

return run
