-- Output utilities for colored terminal printing

local stdio = require("@lune/stdio")
local COLORS = require("./colors")

local output = {}

function output.printColored(message: string, color: string?)
	if color then
		stdio.write(`{color}{message}{COLORS.Reset}\n`)
	else
		stdio.write(`{message}\n`)
	end
end

function output.printError(message: string)
	output.printColored(`Error: {message}`, COLORS.Error)
end

function output.printWarning(message: string)
	output.printColored(`Warning: {message}`, COLORS.Warning)
end

function output.printInfo(message: string)
	output.printColored(message, COLORS.Info)
end

return output
