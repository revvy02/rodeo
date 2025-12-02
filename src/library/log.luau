-- Centralized logging utility
local stdio = require("@lune/stdio")
local config = require("./config")

local colors = config.CLI_LOG_COLORS

local log = {
	verbose = false,
}

function log.setVerbose(enabled: boolean)
	log.verbose = enabled
end

function log.info(msg: string)
	stdio.write(colors.info(msg) .. "\n")
end

function log.success(msg: string)
	stdio.write(colors.success(msg) .. "\n")
end

function log.warn(msg: string)
	stdio.write(colors.warn(msg) .. "\n")
end

function log.error(msg: string)
	stdio.write(colors.error(msg) .. "\n")
end

function log.debug(tag: string, msg: string)
	if log.verbose then
		stdio.write(colors.debug(`[{tag}] {msg}`) .. "\n")
	end
end

-- Raw write (no color, no newline) for special cases
function log.write(msg: string)
	stdio.write(msg)
end

return log
