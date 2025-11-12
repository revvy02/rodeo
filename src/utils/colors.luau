-- Centralized color definitions for consistent styling across the codebase
local chalk = require("@pkg/chalk")

-- Define custom colors using RGB for better saturation/control
local ERROR_RED = chalk.rgb(200, 0, 0) -- Deep saturated red
local WARNING_ORANGE = chalk.rgb(255, 140, 0) -- Orange color for warnings

-- Export color functions with appropriate modifiers
local colors = {
	error = (chalk.bold .. ERROR_RED),
	warning = (chalk.bold .. WARNING_ORANGE),
	info = chalk.cyan,
	success = chalk.green,
	grey = chalk.grey,
	cyan = chalk.cyan,
}

-- Output level color mapping for execution results
colors.levelColors = {
	Print = function(s)
		return s
	end,
	Info = colors.info,
	Warning = colors.warning,
	Error = colors.error,
}

return colors
