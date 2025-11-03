-- rir3 CLI Router
-- Routes commands to appropriate handlers

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local argparse = require("@pkg/argparse")

local COLORS = require("@self/utils/colors")
local output = require("@self/utils/output")

local function showHelp()
	stdio.write(COLORS.Info .. "rir3 - Run Luau code inside Roblox Studio" .. COLORS.Reset .. "\n")
	stdio.write("\n")
	stdio.write("Usage:\n")
	stdio.write("  rir3 <command> [options]\n")
	stdio.write("\n")
	stdio.write("Commands:\n")
	stdio.write("  once <script> [place]    Execute script once in Studio (ephemeral)\n")
	stdio.write("  serve                    Start persistent server for code execution\n")
	stdio.write("  exec <script>            Execute script via running serve instance\n")
	stdio.write("  build                    Build and install the serve plugin\n")
	stdio.write("\n")
	stdio.write("Options:\n")
	stdio.write("  --help, -h              Show this help message\n")
	stdio.write("\n")
	stdio.write("Examples:\n")
	stdio.write("  # One-off execution\n")
	stdio.write("  rir3 once demo/hello.luau\n")
	stdio.write("  rir3 once demo/hello.luau demo/place.rbxl\n")
	stdio.write("\n")
	stdio.write("  # Start persistent server\n")
	stdio.write("  rir3 serve\n")
	stdio.write("\n")
	stdio.write("  # Build and install serve plugin (run once)\n")
	stdio.write("  rir3 build\n")
	stdio.write("\n")
	stdio.write("  # Execute via server (in another terminal)\n")
	stdio.write("  rir3 exec demo/hello.luau\n")
	stdio.write("  rir3 exec demo/hello.luau --timeout 30\n")
	stdio.write("\n")
	stdio.write("For more help on a specific command:\n")
	stdio.write("  rir3 <command> --help\n")
end

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
