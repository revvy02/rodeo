-- rir3 CLI Router
-- Routes commands to appropriate handlers
local argparse = require("@pkg/argparse")

local function main()
	local parser = argparse("rir3", "Run Luau code inside Roblox Studio")

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
	onceCmd:flag("--no-output", "Disable print output")
	onceCmd:flag("--no-logs", "Disable all log output")
	onceCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")

	-- Define serve command
	parser:command("serve", "Start persistent server for code execution")

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
	execCmd:flag("--no-output", "Disable print output")
	execCmd:flag("--no-logs", "Disable all log output")
	execCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")

	-- Define build command
	parser:command("build", "Build and install the serve plugin")

	-- Define status command
	parser:command("status", "Check if rir3 serve is running")

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
	elseif args.status then
		local statusCommand = require("@self/commands/status")
		statusCommand(args)
	end
end

main()
