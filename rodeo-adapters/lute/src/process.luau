-- @lute/process shim — maps to rodeo's process API. Lute's run/system are
-- shape-compatible with rodeo's; only the result field names differ
-- (stdout/stderr vs out/err). pid/onSignal have no host support and error
-- clearly.
local g = _G.__rodeo_procs[_G.__rodeo_eid]

local function mapResult(result)
	return {
		stdout = result.out or "",
		stderr = result.err or "",
		ok = result.ok or false,
		exitcode = result.exitcode or 0,
		signal = nil,
	}
end

local process = {}

process.args = g.process.args
process.env = g.process.env

function process.homedir(): string
	return g.process.homedir()
end

function process.cwd(): string
	return g.process.cwd()
end

function process.run(args: { string }, options)
	return mapResult(g.process.run(args, options))
end

function process.system(command: string, options)
	return mapResult(g.process.system(command, options))
end

function process.exit(exitcode: number)
	g.process.exit(exitcode)
end

function process.execPath(): string
	return g.process.execpath()
end

function process.pid(): number
	error("process.pid is not supported under rodeo (the script runs remotely; there is no meaningful local pid)", 2)
end

function process.onSignal(signal, callback)
	error("process.onSignal is not supported under rodeo (no host RPC for signal handlers)", 2)
end

return process
