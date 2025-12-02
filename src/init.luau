-- rodeo CLI Router
-- Routes commands to appropriate handlers
local argparse = require("@pkg/argparse")
local config = require("@self/library/config")
local log = require("@self/library/log")

local function main()
	local parser = argparse("rodeo", "Run Luau code inside Roblox Studio")
	parser:flag("-v --verbose", "Enable debug output")

	-- Define serve command
	local serveCmd = parser:command("serve", "Start persistent server for code execution")
	serveCmd:option("--port", "Port number for server"):default(config.SERVE_PORT):convert(tonumber)

	-- Define exec command
	local execCmd = parser:command("exec", "Execute script via running serve instance")
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
	execCmd:option("--port", "Port number of running server"):default(config.SERVE_PORT):convert(tonumber)

	-- Define build command
	parser:command("build", "Build and install the serve plugin")

	local args = parser:parse()

	-- Enable verbose logging if flag is set
	log.setVerbose(args.verbose or false)

	-- Router: check which command was invoked and call it with parsed args
	-- When a command is selected, argparse sets result[command_name] = true
	if args.serve then
		local serveCommand = require("@self/commands/serve")
		serveCommand(args)
	elseif args.exec then
		local execCommand = require("@self/commands/exec")
		execCommand(args)
	elseif args.build then
		local buildCommand = require("@self/commands/build")
		buildCommand(args)
	end
end

main()
