-- @rodeo/process API over typed RPC.
local runtime = _G.__rodeo_runtime_proto

-- Apply proto3 defaults: absent fields = zero values
local function applyRunDefaults(resp: runtime.ProcessRunResponse): runtime.ProcessRunResponse
	return {
		ok = if resp.ok ~= nil then resp.ok else false,
		exitcode = resp.exitcode or 0,
		out = resp.out or "",
		err = resp.err or "",
	}
end

return function(rpc, scriptArgs, hostInfo: runtime.ProcessGetInfoResponse)

	local process = {}

	-- Properties
	process.args = scriptArgs

	-- Read-only env proxy
	process.env = setmetatable({}, {
		__index = function(_, key)
			return hostInfo.env[key]
		end,
		__newindex = function()
			error("process.env is read-only in Rodeo (runs remotely)")
		end,
	})

	function process.cwd(): string
		return hostInfo.cwd
	end

	function process.homedir(): string
		return hostInfo.homedir
	end

	function process.execpath(): string
		return hostInfo.execpath
	end

	-- Terminates the run. The code travels via _G (require() replaces error
	-- messages with "Requested module experienced an error...", so a sentinel
	-- string would never reach the runner's xpcall); the error is only the
	-- unwind mechanism. Suspending here instead would leave the run alive
	-- forever. Keep names in sync with rodeo-plugin runner/init.luau and the
	-- log suppressor in rodeo-shared/logging.luau.
	function process.exit(code: number)
		rpc.notify("process_exit", runtime.ProcessExitRequest.new({ code = code }))
		_G.__rodeo_exit_requested = _G.__rodeo_exit_requested or {}
		_G.__rodeo_exit_requested[_G.__rodeo_eid] = code or 0
		error("__RODEO_PROCESS_EXIT__" .. tostring(code or 0), 0)
	end

	function process.run(argsOrHandle, options: any?)
		local resp: runtime.ProcessRunResponse
		if type(argsOrHandle) == "table" and argsOrHandle.__rodeo_pid then
			resp = rpc.call("process_run_handle", runtime.ProcessRunHandleRequest.new({
				pid = argsOrHandle.__rodeo_pid,
			}))
		else
			resp = rpc.call("process_run", runtime.ProcessRunRequest.new({
				args = argsOrHandle,
				options = options,
			}))
		end
		return applyRunDefaults(resp)
	end

	function process.system(command: string, options: any?)
		local resp: runtime.ProcessRunResponse = rpc.call("process_system", runtime.ProcessSystemRequest.new({
			command = command,
			options = options,
		}))
		return applyRunDefaults(resp)
	end

	function process.create(args: { string }, options: any?)
		local result: runtime.ProcessCreateResponse = rpc.call("process_create", runtime.ProcessCreateRequest.new({
			args = args,
			options = options,
		}))
		local handle: any = { __rodeo_pid = result.pid }
		if result.stdinHandle then
			handle.stdin = { __handle = result.stdinHandle }
		end
		if result.stdoutHandle then
			handle.stdout = { __handle = result.stdoutHandle }
		end
		if result.stderrHandle then
			handle.stderr = { __handle = result.stderrHandle }
		end
		return handle
	end

	function process.kill(handle)
		rpc.call("process_kill", runtime.ProcessKillRequest.new({ pid = handle.__rodeo_pid }))
	end

	return process
end
