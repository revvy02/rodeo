-- rodeo CLI Router
-- Routes commands to appropriate handlers
local argparse = require("@pkg/argparse")
local process = require("@lune/process")

local config = require("@self/library/config")
local log = require("@self/library/log")

-- Split process.args at "--" separator into CLI args and script args
-- Returns: cliArgs, scriptArgs, foundSeparator
local function splitArgsAtDoubleDash(rawArgs: { string }): ({ string }, { string }, boolean)
	local cliArgs = {}
	local scriptArgs = {}
	local foundSeparator = false

	for _, arg in ipairs(rawArgs) do
		if arg == "--" and not foundSeparator then
			foundSeparator = true
		elseif foundSeparator then
			table.insert(scriptArgs, arg)
		else
			table.insert(cliArgs, arg)
		end
	end

	return cliArgs, scriptArgs, foundSeparator
end

local function main()
	local parser = argparse("rodeo", "Run Luau code inside Roblox Studio")
	parser:flag("-v --verbose", "Enable debug output")

	-- Define once command
	local onceCmd = parser:command("once", "Execute script once in Studio (ephemeral)")
	onceCmd:argument("script", "Path to the script to execute, or '-' for stdin"):args("?")
	onceCmd:option("-s --source", "Execute source code passed as string")
	onceCmd:option("--place", "Path to the place file to open")
	onceCmd:option("--sourcemap", "Path to sourcemap.json for instance resolution")
	onceCmd:option("--output", "Path to file for execution output (prints/logs)")
	onceCmd:option("--return", "Path to file for return value JSON")
	onceCmd:flag("--show-return", "Print return value to stdout")
	onceCmd:flag("--no-warn", "Disable warning output")
	onceCmd:flag("--no-error", "Disable error output")
	onceCmd:flag("--no-info", "Disable info output")
	onceCmd:flag("--no-print", "Disable print statements")
	onceCmd:flag("--no-output", "Disable all output")
	onceCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")
	onceCmd:option("--port", "Port number for ephemeral server"):default(config.ONCE_PORT):convert(tonumber)

	-- Define serve command
	local serveCmd = parser:command("serve", "Start persistent server for code execution")
	serveCmd:option("--port", "Port number for server"):default(config.SERVE_PORT):convert(tonumber)

	-- Define exec command
	local execCmd = parser:command("exec", "Execute script via serve instance")
	execCmd:argument("script", "Path to the script to execute, or '-' for stdin"):args("?")
	execCmd:option("-s --source", "Execute source code passed as string")
	execCmd:option("--sourcemap", "Path to sourcemap.json for instance resolution")
	execCmd:option("--output", "Path to file for execution output (prints/logs)")
	execCmd:option("--return", "Path to file for return value JSON")
	execCmd:flag("--show-return", "Print return value to stdout")
	execCmd:option("--studio", "Filter: isStudio (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--client", "Filter: isClient (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--server", "Filter: isServer (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--edit", "Filter: isEdit (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--running", "Filter: isRunning (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:flag("--no-warn", "Disable warning output")
	execCmd:flag("--no-error", "Disable error output")
	execCmd:flag("--no-info", "Disable info output")
	execCmd:flag("--no-print", "Disable print statements")
	execCmd:flag("--no-output", "Disable all output")
	execCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")
	execCmd:option("--context", "Execution context: server, client, or plugin"):default("plugin")
	execCmd:option("--host", "Host of running server"):default("localhost")
	execCmd:option("--port", "Port number of running server"):default(config.SERVE_PORT):convert(tonumber)

	-- Define plugin command
	parser:command("plugin", "Build and install the rodeo plugin")

	local cliArgs, scriptArgs, hasCliArgs = splitArgsAtDoubleDash(process.args)
	local args = parser:parse(cliArgs)
	-- Only set scriptArgs if CLI used -- separator (allows directive args to apply otherwise)
	if hasCliArgs then
		args.scriptArgs = scriptArgs
	end

	-- Enable verbose logging if flag is set
	log.setVerbose(args.verbose or false)

	-- Router: check which command was invoked and call it with parsed args
	-- When a command is selected, argparse sets result[command_name] = true
	if args.once then
		local onceCommand = require("@self/commands/once")
		onceCommand(args)
	elseif args.serve then
		local serveCommand = require("@self/commands/serve")
		serveCommand(args)
	elseif args.exec then
		local execCommand = require("@self/commands/exec")
		execCommand(args)
	elseif args.plugin then
		local pluginCommand = require("@self/commands/plugin")
		pluginCommand(args)
	end
end

main()
