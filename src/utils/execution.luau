-- Shared execution utilities for exec and once commands

local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local colors = require("./colors")
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
	local noLogs = args["no_logs"] or false

	return {
		enableWarn = not (args["no_warn"] or noLogs),
		enableError = not (args["no_error"] or noLogs),
		enableInfo = not (args["no_info"] or noLogs),
		enableOutput = not (args["no_output"] or noLogs),
		enableLogs = not noLogs,
	}
end

-- Resolve instance path from sourcemap
local function resolveInstancePath(sourcemapPath: string?, scriptFilePath: string?): string?
	if not sourcemapPath then
		return nil
	end

	if not scriptFilePath then
		stdio.write(colors.warning("Warning: Sourcemap ignored: only works with file-based scripts") .. "\n")
		return nil
	end

	local map, err = sourcemap.loadSourcemap(sourcemapPath)
	if not map then
		stdio.write(colors.error(`Error: {err or "Failed to load sourcemap"}`) .. "\n")
		return nil
	end

	local instancePath = sourcemap.findInstancePath(map, scriptFilePath)
	if not instancePath then
		stdio.write(colors.warning(`Warning: Script not found in sourcemap: {scriptFilePath}`) .. "\n")
		stdio.write(colors.cyan("Falling back to temporary module execution") .. "\n")
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
local function writeExecutionResult(result: string, returnFile: string?)
	if returnFile then
		fs.writeFile(returnFile, result)
	else
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
