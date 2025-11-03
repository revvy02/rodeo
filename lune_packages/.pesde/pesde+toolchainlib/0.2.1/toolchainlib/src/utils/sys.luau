--> Non-exhaustive set of util functions for Linux systems

local process = require("@lune/process")

local ResultExt = require("./ext/result")

local fs = require("../../lune_packages/pathfs").fs
local Result = require("../../lune_packages/result")
local Option = require("../../lune_packages/option")

local sys = {}
sys.consts = {
	S_IFMT = 0xF000,
	S_IFCHR = 0x2000,
}

export type StdioFd = "stdin" | "stdout" | "stderr"
local STDIO_FD_LOOKUP: { [StdioFd]: number } = {
	stdin = 0,
	stdout = 1,
	stderr = 2,
}

function sys.isCharacterDevice(mode: number)
	return bit32.band(mode, sys.consts.S_IFMT) == sys.consts.S_IFCHR
end

function sys.isTTY(fd: number | StdioFd): boolean
	if process.os ~= "linux" then
		-- idk about windows and macOS :p
		return true
	end

	local inputFd: number = if typeof(fd) == "string" then STDIO_FD_LOOKUP[fd] else fd
	local statFd = fs.readFile("/proc/self/stat")
	local pid = assert(string.match(statFd, "^%S+%s+%S+%s+%S+%s+(%S+)"), "Could not get current process PID")

	local stdoutFdMode = ResultExt.ok(
		Result.try(process.exec, "stat", { "-L", "-c", "%f", `/proc/{pid}/fd/{inputFd}` })
	)
		:andThen(function(child: process.ExecResult)
			if not child.ok then
				return Option.None
			end

			return Option.from(tonumber(child.stdout, 16))
		end)

	return stdoutFdMode:isSomeAnd(sys.isCharacterDevice)
end

return sys
