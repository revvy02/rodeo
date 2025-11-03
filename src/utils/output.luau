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

return output
