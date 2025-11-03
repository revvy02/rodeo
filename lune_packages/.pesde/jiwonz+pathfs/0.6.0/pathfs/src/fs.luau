local luneFileSystem = require("@lune/fs")
local gt = require("../luau_packages/greentea")
local vfs = require("./vfs")
local asPathToString = vfs.asPathToString
local types = require("./types")

local AsPathType = types.AsPathType
local booleanType = types.booleanType
local stringType = types.stringType
local ContentsType = types.ContentsType
local arrayOfStringType = types.arrayOfStringType

--[=[
	@class fs

	`require("@lune/fs")` compat module

	### Example
	```lua
	local fs = require("path/to/pathfs").fs

	fs.readFile("path/to/file")
	fs.writeFile("path/to/file", "content")
	```
]=]
local fs = {}

local overwriteOrOptionsType = gt.build(gt.any({ allowNil = true }) :: (luneFileSystem.WriteOptions | boolean)?)
--[=[
	@within fs

	Copies a file or directory recursively to a new path.

	Throws an error if a file or directory already exists at the target path.
	This can be bypassed by passing `true` as the third argument, or a dictionary of options.
	Refer to the documentation for `WriteOptions` for specific option keys and their values.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `from` or write at `to`.
	* Some other I/O error occurred.

	@param from -- The path to copy from
	@param to -- The path to copy to
	@param overwriteOrOptions -- Options for the target path, such as if should be overwritten if it already exists
]=]
function fs.copy(
	from: typeof(AsPathType:type()),
	to: typeof(AsPathType:type()),
	overwriteOrOptions: typeof(overwriteOrOptionsType:type())
)
	assert(AsPathType(from))
	assert(AsPathType(to))
	assert(overwriteOrOptionsType(overwriteOrOptions))

	return luneFileSystem.copy(asPathToString(from), asPathToString(to), overwriteOrOptions)
end

--[=[
	@within fs
	@tag must_use

	Checks if a given path is a directory.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param dirPath -- The directory path to check
	@return boolean -- If the path is a directory or not
]=]
function fs.isDir(dirPath: typeof(AsPathType:type())): typeof(booleanType:type())
	assert(AsPathType(dirPath))

	return luneFileSystem.isDir(asPathToString(dirPath))
end

--[=[
	@within fs
	@tag must_use

	Checks if a given path is a file.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param filePath -- The file path to check
	@return boolean -- If the path is a file or not
]=]
function fs.isFile(filePath: typeof(AsPathType:type())): typeof(booleanType:type())
	assert(AsPathType(filePath))

	return luneFileSystem.isFile(asPathToString(filePath))
end

--[=[
	@within fs
	@tag must_use

	Gets metadata for the given path.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param path -- The path to get metadata for
	@return Metadata -- Metadata for the path
]=]
function fs.metadata(path: typeof(AsPathType:type())): luneFileSystem.Metadata
	assert(AsPathType(path))

	return luneFileSystem.metadata(asPathToString(path))
end

--[=[
	@within fs

	Moves a file or directory to a new path.

	Throws an error if a file or directory already exists at the target path.
	This can be bypassed by passing `true` as the third argument, or a dictionary of options.
	Refer to the documentation for `WriteOptions` for specific option keys and their values.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `from` or write at `to`.
	* The new path exists on a different mount point.
	* Some other I/O error occurred.

	@param from -- The path to move from
	@param to -- The path to move to
	@param overwriteOrOptions -- Options for the target path, such as if should be overwritten if it already exists
]=]
function fs.move(
	from: typeof(AsPathType:type()),
	to: typeof(AsPathType:type()),
	overwriteOrOptions: typeof(overwriteOrOptionsType:type())
)
	assert(AsPathType(from))
	assert(AsPathType(to))
	assert(overwriteOrOptionsType(overwriteOrOptions))

	return luneFileSystem.move(asPathToString(from), asPathToString(to), overwriteOrOptions)
end

--[=[
	@within fs
	@tag must_use

	Reads entries in a directory at `path`.

	An error will be thrown in the following situations:

	* `path` does not point to an existing directory.
	* The current process lacks permissions to read the contents of the directory.
	* Some other I/O error occurred.

	@param dirPath -- The directory path to search in
	@return {string} -- A list of files & directories found
]=]
function fs.readDir(dirPath: typeof(AsPathType:type())): typeof(arrayOfStringType:type())
	assert(AsPathType(dirPath))

	return luneFileSystem.readDir(asPathToString(dirPath))
end

--[=[
	@within fs
	@tag must_use

	Reads a file at `path`.

	An error will be thrown in the following situations:

	* `path` does not point to an existing file.
	* The current process lacks permissions to read the file.
	* Some other I/O error occurred.

	@param filePath -- The path to the file to read
	@return string -- The contents of the file
]=]
function fs.readFile(filePath: typeof(AsPathType:type())): typeof(stringType:type())
	assert(AsPathType(filePath))

	return luneFileSystem.readFile(asPathToString(filePath))
end

--[=[
	@within fs

	Removes a directory and all of its contents.

	An error will be thrown in the following situations:

	* `path` is not an existing and empty directory.
	* The current process lacks permissions to remove the directory.
	* Some other I/O error occurred.

	@param path -- The directory to remove
]=]
function fs.removeDir(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.removeDir(asPathToString(path))
end

--[=[
	@within fs

	Removes a file.

	An error will be thrown in the following situations:

	* `path` does not point to an existing file.
	* The current process lacks permissions to remove the file.
	* Some other I/O error occurred.

	@param path -- The file to remove
]=]
function fs.removeFile(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.removeFile(asPathToString(path))
end

--[=[
	@within fs

	Writes to a file at `path`.

	An error will be thrown in the following situations:

	* The file's parent directory does not exist.
	* The current process lacks permissions to write to the file.
	* Some other I/O error occurred.

	@param path -- The path of the file
	@param contents -- The contents of the file
]=]
function fs.writeFile(path: typeof(AsPathType:type()), contents: typeof(ContentsType:type()))
	assert(AsPathType(path))
	assert(ContentsType(contents))

	return luneFileSystem.writeFile(asPathToString(path), contents)
end

--[=[
	@within fs

	Creates a directory and its parent directories if they are missing.

	An error will be thrown in the following situations:

	* `path` already points to an existing file or directory.
	* The current process lacks permissions to create the directory or its missing parents.
	* Some other I/O error occurred.

	@param path -- The directory to create
]=]
function fs.writeDir(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.writeDir(asPathToString(path))
end

return fs
