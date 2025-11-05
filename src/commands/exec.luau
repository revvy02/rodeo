-- Exec command: Execute script via persistent serve server

local net = require("@lune/net")
local process = require("@lune/process")
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local COLORS = require("../utils/colors")
local output = require("../utils/output")
local uuid = require("../utils/uuid")
local constants = require("../utils/constants")
local sourcemap = require("../utils/sourcemap")

type Config = {
	script: string,
	sourcemap: string?,
}

local function parseArguments(args: any): Config
	return {
		script = args.script,
		sourcemap = args.sourcemap,
	}
end

local function validateConfig(config: Config)
	if not fs.isFile(config.script) then
		output.printError(`Script file not found: {config.script}`)
		process.exit(1)
	end
end

local function checkServerHealth(port: number): boolean
	local success, response = pcall(function()
		return net.request({
			url = `http://localhost:{port}/health`,
			method = "GET",
		})
	end)

	return success and response.ok
end

local function connectToServer(port: number): any
	return net.socket(`ws://localhost:{port}`)
end

local function identifyClient(ws: any)
	ws:send(serde.encode("json", {
		clientType = "exec",
	}))
end

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?)
	local message: any = {
		type = "submit",
		script = script,
		executionId = executionId,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))
end

local function handleMessage(decoded: any, exitCodeRef: { value: number }): boolean
	if decoded.type == "queued" then
		if decoded.position and decoded.position > 1 then
			-- output.printColored(`Queued at position {decoded.position}`, COLORS.Info)
		end
	elseif decoded.type == "output" then
		output.printColored(decoded.body, COLORS[decoded.level] or COLORS.Print)
		if decoded.level == "Error" then
			exitCodeRef.value = 1
		end
	elseif decoded.type == "done" then
		return true
	elseif decoded.type == "disconnect" then
		output.printError("Studio disconnected")
		exitCodeRef.value = 2
		return true
	end

	return false
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	if not checkServerHealth(constants.SERVE_PORT) then
		output.printError(`No rir3 server found on port {constants.SERVE_PORT}. Run 'rir3 serve' first.`)
		process.exit(1)
	end

	local instancePath: string? = nil
	if config.sourcemap then
		local map, err = sourcemap.loadSourcemap(config.sourcemap)
		if not map then
			output.printError(err or "Failed to load sourcemap")
			process.exit(1)
		end

		instancePath = sourcemap.findInstancePath(map, config.script)
		if not instancePath then
			output.printWarning(`Script not found in sourcemap: {config.script}`)
			output.printInfo("Falling back to temporary module execution")
		end
	end

	local scriptContent = fs.readFile(config.script)
	local executionId = uuid.generate()
	local exitCodeRef = { value = 0 }

	local ws = connectToServer(constants.SERVE_PORT)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath)

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)
		local isDone = handleMessage(decoded, exitCodeRef)

		if isDone then
			ws:close()
			break
		end
	end

	process.exit(exitCodeRef.value)
end

return main
