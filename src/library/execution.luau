-- Shared execution utilities for exec and once commands

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local json2luau = require("./json2luau")
local log = require("./log")
local sourcemap = require("./sourcemap")

export type LogFilter = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

-- Build LogFilter from CLI arguments
local function buildLogFilter(args: any): LogFilter
	local noOutput = args["no_output"] or false

	return {
		enableWarn = not (args["no_warn"] or noOutput),
		enableError = not (args["no_error"] or noOutput),
		enableInfo = not (args["no_info"] or noOutput),
		enableOutput = not (args["no_print"] or noOutput),
		enableLogs = not noOutput,
	}
end

-- Resolve instance path from sourcemap
local function resolveInstancePath(sourcemapPath: string?, scriptFilePath: string?): string?
	-- Auto-detect sourcemap.json in cwd if not provided
	local resolvedSourcemapPath = sourcemapPath or sourcemap.findSourcemapInCwd()

	if not resolvedSourcemapPath then
		return nil
	end

	if not scriptFilePath then
		return nil
	end

	local map, err = sourcemap.loadSourcemap(resolvedSourcemapPath)
	if not map then
		log.error(err or "Failed to load sourcemap")
		return nil
	end

	local instancePath = sourcemap.findInstancePath(map, scriptFilePath)
	if not instancePath then
		log.warn(`Script not found in sourcemap: {scriptFilePath}`)
		log.info("Falling back to temporary module execution")
	end

	return instancePath
end

-- Read script content from file or inline source
local function readScriptContent(scriptPath: string?, scriptSource: string?): string
	if scriptSource then
		return scriptSource
	elseif scriptPath then
		return fs.readFile(scriptPath)
	else
		error("No script source provided")
	end
end

-- Write execution output (prints/logs) to file or stdout
local function writeExecutionOutput(text: string, outputFile: string?)
	if outputFile then
		-- Append to file
		local existingContent = ""
		if fs.isFile(outputFile) then
			existingContent = fs.readFile(outputFile)
		end
		fs.writeFile(outputFile, existingContent .. text)
	else
		stdio.write(text)
	end
end

-- Write execution result (return value JSON) to file or stdout
local function writeExecutionResult(result: string, returnFile: string?, showReturn: boolean?)
	if returnFile then
		local output = result
		-- Convert to Luau table syntax if output is a .lua or .luau file
		if returnFile:match("%.luau?$") then
			output = json2luau.parse(result)
		end
		fs.writeFile(returnFile, output)
	end

	if showReturn then
		stdio.write(result)
		stdio.write("\n")
	end
end

return {
	buildLogFilter = buildLogFilter,
	resolveInstancePath = resolveInstancePath,
	readScriptContent = readScriptContent,
	writeExecutionOutput = writeExecutionOutput,
	writeExecutionResult = writeExecutionResult,
}
