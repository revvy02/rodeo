local types = require("./types")
local AsPathType = types.AsPathType
local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path
local process = require("@lune/process")
local normalizePath = require("./normalizePath")

type Path = luauPath.Path
type AsPath = luauPath.AsPath

--[=[
	@class vfs
	@private
]=]
local vfs = {}

local currentDir: Path?

local cwd = normalizePath(process.cwd)

function vfs.createPath(path: AsPath): Path
	-- selene: allow(shadowing)
	local path = Path.from(path)
	if currentDir and not path:isAbsolute() then
		return currentDir:join(path)
	end
	return path
end

function vfs.asPathToString(asPath: AsPath): string
	if type(asPath) == "string" then
		return asPath
	end
	return vfs.createPath(asPath):toString()
end

--[=[
	@within vfs

	Sets the current directory path virtually.

	An error will be thrown in the following situations:

	* Given path is not a relative path.
]=]
function vfs.setCurrentDir(path: AsPath)
	assert(AsPathType(path))

	local newCurrentDir: Path = Path.from(vfs.asPathToString(path))
	if not newCurrentDir:isRelative() then
		error("Current path must be a relative path")
	end
	currentDir = newCurrentDir
	cwd = normalizePath(Path.from(process.cwd):join(newCurrentDir))
end

--[=[
	@within pathfs

	Returns the current working directory as an absolute path.

	@return Path -- The current working directory
]=]
function vfs.cwd(): Path
	return cwd
end

return vfs
