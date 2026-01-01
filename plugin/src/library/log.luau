-- Debug logging utility for rodeo plugin
-- Provides formatted debug output with source location

local terminal = require(script.Parent.terminal)

local VERBOSE = false

local function setVerbose(enabled: boolean)
	VERBOSE = enabled
end

local function isVerbose(): boolean
	return VERBOSE
end

local function log(message: string)
	if VERBOSE then
		local source, line, name = debug.info(2, "sln")
		local formattedSource = terminal.style.gray(source)
		local formattedLine = terminal.style.red(tostring(line))
		local formattedName = terminal.style.green(name or "?")
		print(`[{formattedSource}:{formattedLine} {formattedName}] {message}`)
	end
end

return {
	setVerbose = setVerbose,
	isVerbose = isVerbose,
	log = log,
}
