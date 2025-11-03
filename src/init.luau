-- rir3 CLI Router
-- Routes commands to appropriate handlers
local argparse = require("@pkg/argparse")

local function main()
	local parser = argparse("rir3", "Run Luau code inside Roblox Studio")

	-- Define once command
	local onceCmd = parser:command("once", "Execute script once in Studio (ephemeral)")
	onceCmd:argument("script", "Path to the script to execute")
	onceCmd:option("-p --place", "Path to the place file to open")
	onceCmd:option("--port", "Port to use for WebSocket server"):default("34872"):convert(tonumber)
	onceCmd:option("--ignore-pattern", "Regex patterns to ignore in error messages"):count("*")

	-- Define serve command
	local serveCmd = parser:command("serve", "Start persistent server for code execution")
	serveCmd:option("--port", "Port to use for WebSocket server"):default("34872"):convert(tonumber)

	-- Define exec command
	local execCmd = parser:command("exec", "Execute script via running serve instance")
	execCmd:argument("script", "Path to the script to execute")
	execCmd:option("--port", "Port of the rir3 serve server"):default("34872"):convert(tonumber)
	execCmd:option("--timeout", "Execution timeout in seconds"):default("300"):convert(tonumber)

	-- Define build command
	local buildCmd = parser:command("build", "Build and install the serve plugin")
	buildCmd:option("--port", "Port to configure the plugin for"):default("34872"):convert(tonumber)

	local args = parser:parse()

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
	elseif args.build then
		local buildCommand = require("@self/commands/build")
		buildCommand(args)
	end
end

main()
