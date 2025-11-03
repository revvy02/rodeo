local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local PLATFORM_SEP = if process.os == "windows" then "\\" else "/"
_G.interactive = false

-- A mapping of things to do depending on the file present
local PATH_ACTION_MAP: { [string]: (dir: string) -> number? } = {
	["default.project.json"] = function(dir)
		return process.exec("rojo", { "sourcemap", dir }, {
			cwd = process.cwd,
			env = process.env,
			stdio = "forward",
		}).code
	end,

	["init.lua"] = function()
		return stdio.write(
			serde.encode("json", { filePaths = { "init.lua" } }, false)
		)
	end,
	["init.luau"] = function()
		return stdio.write(
			serde.encode("json", { filePaths = { "init.luau" } }, false)
		)
	end,
}

--- Writes a Rojo sourcemap for the project in the provided directory or the current
--- working directory to standard output.

--- ## Errors
--- * The current process lacks permissions to a file
--- * Failure to spawn `rojo` command
--- * Any I/O error occurs
return function(packageDirectory: string?): boolean
	packageDirectory = packageDirectory or process.cwd

	-- We go through the action mappings in order of priority and check for the
	-- file predicates, if present, we execute the action and report our status
	for path, action in PATH_ACTION_MAP do
		if fs.isFile(`{packageDirectory}{PLATFORM_SEP}{path}`) then
			local status = action(packageDirectory :: string)
			return if status ~= nil then status == 0 else true
		end
	end

	-- If we reached so far, that must mean none of the file predicates matched,
	-- so we return a `false` signifying an error
	return false
end
