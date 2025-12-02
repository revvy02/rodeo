-- Global configuration: constants and colors
local chalk = require("@pkg/chalk")

local ERROR_RED = chalk.rgb(200, 0, 0)
local WARNING_ORANGE = chalk.rgb(255, 140, 0)

return {
	-- Ports
	SERVE_PORT = 44872,

	-- Bit positions for run context bitset
	CONTEXT_BITS = {
		isStudio = 0,
		isServer = 1,
		isClient = 2,
		isEdit = 3,
		isRunning = 4,
	},

	-- Colors for CLI messages (rodeo's own output)
	CLI_LOG_COLORS = {
		error = (chalk.bold .. ERROR_RED),
		warn = (chalk.bold .. WARNING_ORANGE),
		info = chalk.cyan,
		success = chalk.green,
		debug = chalk.grey,
	},

	-- Colors for execution output (from Studio)
	EXEC_LOG_COLORS = {
		Print = function(s)
			return s
		end,
		Info = chalk.cyan,
		Warning = (chalk.bold .. WARNING_ORANGE),
		Error = (chalk.bold .. ERROR_RED),
	},
}
