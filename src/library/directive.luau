-- Shared directive parsing utilities for run and once commands

local fs = require("@lune/fs")

-- Resolve script path, checking .rodeo/ directory for simple names
local function resolveScriptPath(scriptArg: string): string
	if string.find(scriptArg, "/") or string.find(scriptArg, "\\") then
		return scriptArg
	end

	local rodeoDir = ".rodeo"
	if fs.isDir(rodeoDir) then
		local withExt = `{rodeoDir}/{scriptArg}.luau`
		if fs.isFile(withExt) then
			return withExt
		end

		local asIs = `{rodeoDir}/{scriptArg}`
		if fs.isFile(asIs) then
			return asIs
		end
	end

	return scriptArg
end

-- Parse flags from directive string (--key value pairs and standalone flags)
local function parseDirectiveFlags(directive: string): { [string]: any }
	local result: { [string]: any } = {}

	-- Parse quoted values first
	for key, value in string.gmatch(directive, '%-%-([%w-]+)%s+"([^"]+)"') do
		local numValue = tonumber(value)
		result[key] = numValue or value
	end
	-- Parse unquoted values
	for key, value in string.gmatch(directive, "%-%-([%w-]+)%s+([^%-%s\"][^%s]*)") do
		if not result[key] then
			local numValue = tonumber(value)
			result[key] = numValue or value
		end
	end

	-- Parse standalone flags
	local endFlag = string.match(directive, "%-%-([%w-]+)%s*$")
	if endFlag and not result[endFlag] then
		result[endFlag] = true
	end
	for flag in string.gmatch(directive, "%-%-([%w-]+)%s+%-%-") do
		if not result[flag] then
			result[flag] = true
		end
	end

	return result
end

-- Apply directive flags to args (CLI args override directive)
local function applyDirective(args: any, directive: { [string]: any })
	for key, value in pairs(directive) do
		local argKey = string.gsub(key, "-", "_")
		if args[argKey] == nil then
			args[argKey] = value
		end
	end
end

return {
	resolveScriptPath = resolveScriptPath,
	parseDirectiveFlags = parseDirectiveFlags,
	applyDirective = applyDirective,
}
