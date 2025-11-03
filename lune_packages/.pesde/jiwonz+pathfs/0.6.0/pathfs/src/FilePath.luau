local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path
local fs = require("./fs")
local types = require("./types")

local PathType = types.PathType
local AsPathType = types.AsPathType
local ContentsType = types.ContentsType
local optionalBooleanType = types.optionalBooleanType
local stringType = types.stringType
local booleanType = types.booleanType

export type FilePath = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: FilePathImpl)
)

type FilePathImpl = {
	__index: FilePathImpl,
	__tostring: (self: FilePath) -> string,
	new: (filePath: typeof(AsPathType:type())) -> FilePath,
	fromExisting: (filePath: typeof(AsPathType:type())) -> FilePath,
	withFileWritten: (
		self: FilePath,
		contents: typeof(ContentsType:type()),
		allowOverwrite: typeof(optionalBooleanType:type())
	) -> FilePath,
	is: (value: any) -> boolean,
	isFile: (self: FilePath) -> typeof(booleanType:type()),
	readFile: (self: FilePath) -> typeof(stringType:type()),
	writeFile: (self: FilePath, contents: typeof(ContentsType:type())) -> (),
	removeFile: (self: FilePath) -> (),
}

--[=[
	@class FilePath

	Represents a file path.

	### Example
	```lua
	local filePath = FilePath.fromExisting("path/to/file")
	filePath:writeFile("content")
	```
]=]
local FilePath = {} :: FilePathImpl
FilePath.__index = FilePath
--[=[
	@within FilePath
	@prop path Path
	The underlying `Path` instance.
]=]

--[=[
	@within FilePath

	Returns a string representation of the `FilePath` instance.

	### Example
	```lua
	local filePath = FilePath.fromExisting("path/to/file")
	print(filePath) -- Output: FilePath<path/to/file>
	```

	@param self FilePath -- The FilePath instance
	@return string -- A string representation of the FilePath instance
]=]
function FilePath.__tostring(self)
	assert(PathType(self.path))

	return `FilePath<{self.path}>`
end

--[=[
	@within FilePath

	Creates a new `FilePath` instance.

	@param filePath AsPath -- The file path
	@return FilePath -- A new `FilePath` instance
]=]
function FilePath.new(filePath)
	assert(AsPathType(filePath))

	return setmetatable({
		path = Path.from(filePath),
	}, FilePath)
end

--[=[
	@within FilePath

	Creates a new `FilePath` instance from an existing file path.

	An error will be thrown if there is no file at the given path.

	@param filePath AsPath -- The existing file path
	@return FilePath -- A new `FilePath` instance
]=]
function FilePath.fromExisting(filePath)
	assert(AsPathType(filePath))

	if not fs.isFile(filePath) then
		error(`There is no file at that path({filePath})`)
	end

	return setmetatable({
		path = Path.from(filePath),
	}, FilePath)
end

--[=[
	@within FilePath

	Writes the file to the filesystem.

	An error will be thrown in the following situations:

	* The current process lacks permissions to write the file.
	* Some other I/O error occurred.

	### Example
	```lua
	local filePath = FilePath.new("path/to/file"):withFileWritten("content")
	```

	@param self FilePath -- The FilePath instance
	@param contents Contents -- The contents to write to the file
	@param allowOverwrite boolean? -- Whether to allow overwriting an existing file. Defaults to `false`.
	@return FilePath -- The `FilePath` instance
]=]
function FilePath.withFileWritten(self, contents, allowOverwrite)
	assert(ContentsType(contents))
	assert(optionalBooleanType(allowOverwrite))

	if self:isFile() then
		if allowOverwrite then
			self:removeFile()
		else
			error(`Not allowed to overwrite a file. A file already exists at that path({self.path})`)
		end
	end
	if fs.isDir(self.path) then
		error(`Cannot create a new file. The directory already exists at that path({self.path})`)
	end
	self:writeFile(contents)

	return self
end

--[=[
	@within FilePath

	Checks if a value is a `FilePath` instance.

	@param value any -- The value to check
	@return boolean -- Whether the value is a `FilePath` instance
]=]
function FilePath.is(value)
	return type(value) == "table" and getmetatable(value) == FilePath
end

--[=[
	@within FilePath
	@tag must_use

	Checks if the file exists at the path.

	@param self FilePath -- The FilePath instance
	@return boolean -- Whether the file exists at the path
]=]
function FilePath.isFile(self)
	return fs.isFile(self.path)
end

--[=[
	@within FilePath
	@tag must_use

	Reads the file contents.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
	@return string -- The file contents
]=]
function FilePath.readFile(self)
	return fs.readFile(self.path)
end

--[=[
	@within FilePath

	Writes contents to the file.

	An error will be thrown in the following situations:

	* The current process lacks permissions to write the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
	@param contents Contents -- The contents to write to the file
]=]
function FilePath.writeFile(self, contents)
	return fs.writeFile(self.path, contents)
end

--[=[
	@within FilePath

	Removes the file.

	An error will be thrown in the following situations:

	* The file does not exist.
	* The current process lacks permissions to remove the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
]=]
function FilePath.removeFile(self)
	return fs.removeFile(self.path)
end

return FilePath
