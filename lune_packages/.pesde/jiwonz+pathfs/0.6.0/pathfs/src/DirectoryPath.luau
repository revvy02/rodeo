local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path
local fs = require("./fs")
local types = require("./types")

local PathType = types.PathType
local AsPathType = types.AsPathType
local optionalBooleanType = types.optionalBooleanType
local arrayOfStringType = types.arrayOfStringType
local booleanType = types.booleanType

export type DirectoryPath = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: DirectoryPathImpl
))

type DirectoryPathImpl = {
	__index: DirectoryPathImpl,
	__tostring: (self: DirectoryPath) -> string,
	new: (dirPath: typeof(AsPathType:type())) -> DirectoryPath,
	fromExisting: (dirPath: typeof(AsPathType:type())) -> DirectoryPath,
	withDirWritten: (self: DirectoryPath, allowOverwrite: typeof(optionalBooleanType:type())) -> DirectoryPath,
	is: (value: any) -> boolean,
	isDir: (self: DirectoryPath) -> typeof(booleanType:type()),
	readDir: (self: DirectoryPath) -> typeof(arrayOfStringType:type()),
	writeDir: (self: DirectoryPath) -> (),
	removeDir: (self: DirectoryPath) -> (),
}

--[=[
	@class DirectoryPath

	Represents a directory path.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	dirPath:removeDir()
	```
]=]
local DirectoryPath = {} :: DirectoryPathImpl
DirectoryPath.__index = DirectoryPath
--[=[
	@within DirectoryPath
	@prop path Path
	The underlying `Path` instance.
]=]

--[=[
	@within DirectoryPath

	Returns a string representation of the `DirectoryPath` instance.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	print(dirPath) -- Output: DirectoryPath<path/to/dir>
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@return string -- A string representation of the DirectoryPath instance
]=]
function DirectoryPath.__tostring(self)
	assert(PathType(self.path))

	return `DirectoryPath<{self.path}>`
end

--[=[
	@within DirectoryPath

	Creates a new `DirectoryPath` instance.

	@param dirPath AsPath -- The directory path
	@return DirectoryPath -- A new `DirectoryPath` instance
]=]
function DirectoryPath.new(dirPath)
	assert(AsPathType(dirPath))

	return setmetatable({
		path = Path.from(dirPath),
	}, DirectoryPath)
end

--[=[
	@within DirectoryPath

	Creates a new `DirectoryPath` instance from an existing directory.

	An error will be thrown if the directory does not exist.

	@param dirPath AsPath -- The directory path
	@return DirectoryPath -- A new `DirectoryPath` instance
]=]
function DirectoryPath.fromExisting(dirPath)
	assert(AsPathType(dirPath))

	if not fs.isDir(dirPath) then
		error(`There is no directory at that path({dirPath})`)
	end

	return setmetatable({
		path = Path.from(dirPath),
	}, DirectoryPath)
end

--[=[
	@within DirectoryPath

	Writes the directory to the filesystem if it does not already exist.

	An error will be thrown in the following situations:

	* A file already exists at the directory path.
	* The current process lacks permissions to write the directory.
	* Some other I/O error occurred.

	### Example
	```lua
	local dirPath = DirectoryPath.new("path/to/dir"):withDirWritten()
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@param allowOverwrite boolean? -- Whether to allow overwriting an existing directory. Defaults to `false`.
	@return DirectoryPath -- The `DirectoryPath` instance
]=]
function DirectoryPath.withDirWritten(self, allowOverwrite)
	assert(optionalBooleanType(allowOverwrite))

	if self:isDir() then
		if allowOverwrite then
			self:removeDir()
		else
			error(`Not allowed to overwrite a directory. A directory already exists at that path({self.path})`)
		end
	end
	if fs.isFile(self.path) then
		error(`Cannot write a directory. The file already exists at that path({self.path})`)
	end
	self:writeDir()

	return self
end

--[=[
	@within DirectoryPath

	Checks if a value is a `DirectoryPath` instance.

	@param value any -- The value to check
	@return boolean -- Whether the value is a `DirectoryPath` instance
]=]
function DirectoryPath.is(value)
	return type(value) == "table" and getmetatable(value) == DirectoryPath
end

--[=[
	@within DirectoryPath
	@tag must_use

	Checks if the directory exists.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at the directory path.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
	@return boolean -- Whether the directory exists
]=]
function DirectoryPath.isDir(self)
	return fs.isDir(self.path)
end

--[=[
	@within DirectoryPath
	@tag must_use

	Reads the contents of the directory.

	An error will be thrown in the following situations:

	* The directory does not exist.
	* The current process lacks permissions to read at the directory path.
	* Some other I/O error occurred.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	for _, name in dirPath:readDir() do
		print(name)
	end
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@return { string } -- A table containing the entries in the directory
]=]
function DirectoryPath.readDir(self)
	return fs.readDir(self.path)
end

--[=[
	@within DirectoryPath

	Writes the directory to the filesystem.

	An error will be thrown in the following situations:

	* A file already exists at the directory path.
	* The current process lacks permissions to write the directory.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
]=]
function DirectoryPath.writeDir(self)
	return fs.writeDir(self.path)
end

--[=[
	@within DirectoryPath

	Removes the directory from the filesystem.

	An error will be thrown in the following situations:

	* The directory does not exist.
	* The current process lacks permissions to remove the directory.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
]=]
function DirectoryPath.removeDir(self)
	return fs.removeDir(self.path)
end

return DirectoryPath
