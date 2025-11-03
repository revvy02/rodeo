local process = require("@lune/process")
local pathSeparator = process.os == "windows" and "\\" or "/"
-- selene: allow(global_usage)
_G.SYS_PATH_SEPARATOR = pathSeparator
local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path
local fs = require("./fs")
local gt = require("../luau_packages/greentea")
local types = require("./types")
local vfs = require("./vfs")
local createPath = vfs.createPath
local normalizePath = require("./normalizePath")
local cwd = vfs.cwd
local DirectoryPath = require("./DirectoryPath")
local luneFileSystem = require("@lune/fs")
local FilePath = require("./FilePath")
local task = require("@lune/task")
local serde = require("@lune/serde")

export type DirectoryPath = DirectoryPath.DirectoryPath
export type FilePath = FilePath.FilePath
export type Metadata = luneFileSystem.Metadata
export type MetadataKind = luneFileSystem.MetadataKind
export type MetadataPermissions = luneFileSystem.MetadataPermissions
export type WriteOptions = luneFileSystem.WriteOptions
export type Components = types.Components
export type Path = luauPath.Path
export type AsPath = luauPath.AsPath
export type Component = types.Component
local PathType = types.PathType
local AsPathType = types.AsPathType
local optionalBooleanType = types.optionalBooleanType
local ContentsType = types.ContentsType

--[=[
	@class pathfs

	luau-path + @lune/fs with some utilities
]=]
local pathfs = {}
--[=[
	@prop fs fs
	@within pathfs
]=]
pathfs.fs = fs
--[=[
	@prop DirectoryPath DirectoryPath
	@within pathfs
]=]
pathfs.DirectoryPath = DirectoryPath
--[=[
	@prop FilePath FilePath
	@within pathfs
]=]
pathfs.FilePath = FilePath
--[=[
	@prop pathSeparator string
	@within pathfs

	Current path separator

	### Example
	```lua
	if process.os == "windows" then
		print(pathfs.pathSeparator) -- "\\" (Windows)
	else
		print(pathfs.pathSeparator) -- "/" (other OS, maybe Linux)
	end
	```
]=]
pathfs.pathSeparator = pathSeparator
--[=[
	@external Component https://github.com/seaofvoices/luau-path/blob/main/src/Component.luau
	@prop Component Component
	@within pathfs

	A `Component` class exported from `luau-path`
]=]
pathfs.Component = getmetatable(Path.from("a"):components():collect()[1] :: any).__index :: Component & {
	normal: (value: string) -> Component,
	rootDir: () -> Component,
	curDir: () -> Component,
	parentDir: () -> Component,
	prefix: (raw: string, prefix: any) -> Component,
}
pathfs.normalize = normalizePath
pathfs.cwd = cwd
--[=[
	@prop Path Path
	@within pathfs

	A `Path` class exported from `luau-path`

	### Example
	```lua
	local path = Path.from("path/to/file")
	```
]=]
pathfs.Path = Path

local function extendTable<K, V>(target: { V }, tbl: { [K]: V })
	for _, v in tbl do
		table.insert(target, v)
	end
end

local optionalNumberType = gt.build(gt.opt(gt.number()))
--[=[
	@within pathfs

	Gets current script context's path. (default level is `2`)

	An error will be thrown in the following situations:

	* script path found in `debug.info(level)` is not resolvable.
]=]
function pathfs.script(level: typeof(optionalNumberType:type())): typeof(PathType:type())
	assert(optionalNumberType(level))

	local path = string.match(debug.info(level or 2, "s"), '%[string "([^"]*)"%]')
	if path then
		local luauOne = path .. ".luau"
		local luaOne = path .. ".lua"

		if fs.isFile(luauOne) then
			return Path.from(luauOne)
		elseif fs.isFile(luaOne) then
			return Path.from(luaOne)
		elseif fs.isFile(path) then
			return Path.from(path)
		end
	end

	error("Failed to get script path")
end

--[=[
	@within pathfs

	Gets absolute path of given path just by joining the `pathfs.cwd` and the path.
]=]
function pathfs.absolute(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)

	if path:isAbsolute() then
		return path
	end

	return normalizePath(cwd():join(path))
end

--[=[
	@within pathfs

	Gets a path without the current directory component.
]=]
function pathfs.withoutCurDir(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local components = path:components()
	local firstComponent = components:next()
	if firstComponent and firstComponent.type == "curDir" then
		return createPath(components)
	end

	return path
end

local optionalPathType = gt.build(gt.opt(PathType:type()))
local optionalStringType = gt.build(gt.opt(gt.string()))
--[=[
	@within pathfs

	Construct a relative path from a provided base directory path to the provided path.

	Implementation inspired by https://github.com/Manishearth/pathdiff
]=]
function pathfs.diff(
	target: typeof(AsPathType:type()),
	base: typeof(AsPathType:type()),
	separator: typeof(optionalStringType:type())
): typeof(optionalPathType:type())
	assert(AsPathType(target))
	assert(AsPathType(base))
	assert(optionalStringType(separator))

	separator = separator or pathfs.pathSeparator
	-- selene: allow(shadowing)
	local target = createPath(target)
	-- selene: allow(shadowing)
	local base = createPath(base)

	if target:isAbsolute() ~= base:isAbsolute() then
		if target:isAbsolute() then
			return target
		else
			return
		end
	else
		local ita = target:components()
		local itb = base:components()
		local comps = {}
		while true do
			local a, b = ita:next(), itb:next()
			if not a and not b then
				break
			elseif a and not b then
				table.insert(comps, a)
				extendTable(comps, ita:collect())
			elseif not a then
				table.insert(comps, pathfs.Component.parentDir())
			elseif a and b and #comps == 0 and a == b then
				continue
			elseif a and b and b.type == "curDir" then
				table.insert(comps, a)
			elseif a and b and b.type == "parentDir" then
				return
			elseif a and b then
				table.insert(comps, pathfs.Component.parentDir())
				for _, _ in itb do
					table.insert(comps, pathfs.Component.parentDir())
				end
				table.insert(comps, a)
				extendTable(comps, ita:collect())
				break
			end
		end
		local strComps = {}
		for _, comp in comps do
			table.insert(strComps, comp:toString())
		end
		return Path.from(table.concat(strComps, separator))
	end
end

--[=[
	@within pathfs

	Returns the canonical, absolute form of a path with all intermediate components normalized and symbolic links resolved.
]=]
function pathfs.canonicalize(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local absolutePath = pathfs.absolute(path)
	if fs.isFile(absolutePath) or fs.isDir(absolutePath) then
		return absolutePath
	end

	error(`Failed to canonicalize the path('{path}'). does not exist`)
end

--[=[
	@within pathfs

	Creates a new `Path` based on the current dir path.

	An error will be thrown in the following situations:

	* Errors while calling `pathfs.script(3)`.
	* Current script path's parent path does not exist.
]=]
function pathfs.fromDir(
	path: typeof(AsPathType:type()),
	relative: typeof(optionalBooleanType:type())
): typeof(PathType:type())
	assert(AsPathType(path))
	assert(optionalBooleanType(relative))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local currentScriptPath = pathfs.script(3)
	local resolved = if relative == true then currentScriptPath else pathfs.canonicalize(currentScriptPath)
	local parent = resolved:parent()
	if parent then
		return parent:join(path)
	end
	error("Failed to perform 'fromDir'. parent does not exist in the script path")
end

--[=[
	@within pathfs

	Get the dir path based on the current script context.

	An error will be thrown in the following situations:

	* Errors while calling `pathfs.getScriptPath()`.
	* Current script path's parent path does not exist.
]=]
function pathfs.getDir(relative: typeof(optionalBooleanType:type())): typeof(PathType:type())
	assert(optionalBooleanType(relative))

	local currentScriptPath = pathfs.script(3)
	local resolved = if relative == true then currentScriptPath else pathfs.canonicalize(currentScriptPath)
	local parent = resolved:parent()
	if parent then
		return parent
	end
	error("Failed to get dir path. parent does not exist in the script path")
end

--[=[
	@within pathfs

	Finds a file at the given file path.
	@param filePath -- The path to the file, of type AsPathType.
	@return FilePath? -- A File object if the file exists, otherwise nil.
]=]
function pathfs.findFile(filePath: typeof(AsPathType:type())): FilePath?
	assert(AsPathType(filePath))

	-- selene: allow(shadowing)
	local dirPath = createPath(filePath)
	if fs.isFile(dirPath) then
		return FilePath.fromExisting(dirPath)
	end

	return
end

--[=[
	@within pathfs

	Finds a directory at the given directory path.
	@param dirPath -- The path to the directory, of type AsPathType.
	@return DirectoryPath? -- A Directory object if the directory exists, otherwise nil.
]=]
function pathfs.findDir(dirPath: typeof(AsPathType:type())): DirectoryPath?
	assert(AsPathType(dirPath))

	-- selene: allow(shadowing)
	local dirPath = createPath(dirPath)
	if fs.isDir(dirPath) then
		return DirectoryPath.fromExisting(dirPath)
	end

	return
end

local directoryType = gt.build(gt.union(
	gt.custom(DirectoryPath.is, "DirectoryPath"),
	AsPathType:type()
))

--[=[
	@within pathfs
	@interface DirEntry
	.name string -- File name of this directory entry without any leading path component(s)
	.file FilePath? -- File object if it exists
	.dir DirectoryPath? -- Directory object if it exists
	.path Path -- The full path of this directory entry

	A directory entry object.
]=]
export type DirEntry = {
	name: string,
	file: FilePath?,
	dir: DirectoryPath?,
	path: Path,
}

local function hashDirEntry(entry: DirEntry): string
	return entry.path:toString()
end

local function directoryToPath(dir: typeof(directoryType:type())): typeof(PathType:type())
	local path: typeof(PathType:type()) = if DirectoryPath.is(dir)
		then (dir :: DirectoryPath).path
		else createPath(dir :: typeof(AsPathType:type()))

	if not fs.isDir(path) then
		error(`The provided path \`{path}\` is not a valid directory`)
	end

	return path
end

--[=[
	@within pathfs

	Get the entries of a directory.

	### Example
	```lua
	for _, entry in pathfs.getEntries("path/to/dir") do
		print(entry.name) -- File name of this directory entry without any leading path component(s)
		print(entry.file) -- File object if it exists
		print(entry.directory) -- Directory object if it exists
	end
	```

	@param directory -- The directory to get entries from, of type Directory or AsPathType.
	@return { DirEntry } -- A table containing the entries in the directory.
]=]
function pathfs.getEntries(directory: typeof(directoryType:type())): { DirEntry }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry } = {}

	for _, entryName in fs.readDir(directory) do
		local path = directory:join(entryName)
		table.insert(entries, {
			name = entryName,
			file = pathfs.findFile(path),
			dir = pathfs.findDir(path),
			path = path,
		})
	end

	return entries
end

--[=[
	@within pathfs

	Get the entries of a directory.

	### Example
	```lua
	for _, entry in pathfs.getDescendantEntries("path/to/dir") do
		print(entry.name) -- File name of this directory entry without any leading path component(s)
		print(entry.file) -- File object if it exists
		print(entry.directory) -- Directory object if it exists
	end
	```

	@param directory -- The directory to get entries from, of type Directory or AsPathType.
	@return { DirEntry } -- A table containing the entries in the directory.
]=]
function pathfs.getDescendantEntries(directory: typeof(directoryType:type())): { DirEntry }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry } = {}

	for _, entryName in fs.readDir(directory) do
		local path = directory:join(entryName)

		table.insert(entries, {
			name = entryName,
			file = pathfs.findFile(path),
			directory = pathfs.findDir(path),
			path = path,
		})

		if fs.isDir(path) then
			local deepEntries = pathfs.getDescendantEntries(path)

			for _, deepEntry: DirEntry in deepEntries do
				table.insert(entries, deepEntry)
			end
		end
	end

	return entries
end

-- original source credits to: https://github.com/ffrostfall/lunePackages/blob/e6335a8c44957afbf1b00e3ecca37ac6a03af14d/watch/init.luau
local function watchPaths(paths: { string }, callback: () -> ())
	local lastModified = {}

	for _, path in paths do
		lastModified[path] = fs.metadata(path).modifiedAt
	end

	while true do
		local changed = false

		for path, modified in lastModified do
			local newModified = fs.metadata(path).modifiedAt
			if newModified ~= modified then
				lastModified[path] = newModified
				changed = true
				break
			end
		end

		if changed then
			task.spawn(callback)
		end

		task.wait(1)
	end
end

local directoriesArrayType = gt.build(gt.array(directoryType:type()))
local callbackType = gt.build(gt.anyfn())
--[=[
	@within pathfs

	Watch directories for changes.

	### Example
	```lua
	pathfs.watchDirectories({"path/to/dir1", "path/to/dir2"}, function()
		print("Changed!")
	end)
	```
]=]
function pathfs.watchDirectories(
	directories: typeof(directoriesArrayType:type()),
	onChanged: typeof(callbackType:type())
): thread
	assert(directoriesArrayType(directories))
	assert(callbackType(onChanged))

	local paths = {}

	for _, dir in directories do
		-- selene: allow(shadowing)
		local dir = directoryToPath(dir)
		for _, filePath in pathfs.getDescendantEntries(dir) do
			table.insert(paths, filePath.path:toString())
		end
	end

	task.spawn(onChanged)
	return task.spawn(watchPaths, paths, onChanged)
end

--[=[
	@within pathfs

	Watch a file for changes.

	### Example
	```lua
	pathfs.watchFile("path/to/file", function()
		print("Changed!")
	end)
	```
]=]
function pathfs.watchFile(fileName: typeof(AsPathType:type()), onChanged: typeof(callbackType:type())): thread
	assert(AsPathType(fileName))
	assert(callbackType(onChanged))

	task.spawn(onChanged)
	return task.spawn(function()
		local lastModified = fs.metadata(fileName).modifiedAt

		while true do
			local newModified = fs.metadata(fileName).modifiedAt
			if newModified ~= lastModified then
				task.spawn(onChanged)

				lastModified = newModified
			end

			task.wait(1)
		end
	end)
end

local function watchEntryAdded(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry },
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onAdded))

	local oldEntries: { [string]: DirEntry } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry } = {}
			do
				local ok, entries = pcall(getEntries, directory)
				if not ok then -- This may no longer be a valid directory
					return
				end
				for _, entry in entries do
					newEntries[hashDirEntry(entry)] = entry
				end
			end
			for _, newEntry in newEntries do
				if not oldEntries[hashDirEntry(newEntry)] then
					task.spawn(onAdded, newEntry)
				end
			end

			oldEntries = newEntries

			task.wait(1)
		end
	end)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for added entries.

	### Example
	```lua
	pathfs.watchEntryAdded("path/to/dir", function(addedEntry)
		print("Added entry:", addedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onAdded -- The callback function to call when an entry is added.
]=]
function pathfs.watchEntryAdded(
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchEntryAdded is deprecated and will be removed in future releases")

	return watchEntryAdded(pathfs.getEntries, directory, onAdded)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for added descendant entries.

	### Example
	```lua
	pathfs.watchDescendantEntryAdded("path/to/dir", function(addedEntry)
		print("Added entry:", addedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onAdded -- The callback function to call when an entry is added.
]=]
function pathfs.watchDescendantEntryAdded(
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryAdded is deprecated and will be removed in future releases")

	return watchEntryAdded(pathfs.getDescendantEntries, directory, onAdded)
end

local function watchEntryRemoved(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry },
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onRemoved))

	local oldEntries: { [string]: DirEntry } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry } = {}
			do
				local ok, entries = pcall(getEntries, directory)
				if not ok then -- This may no longer be a valid directory
					return
				end
				for _, entry in entries do
					newEntries[hashDirEntry(entry)] = entry
				end
			end
			for _, oldEntry in oldEntries do
				if not newEntries[hashDirEntry(oldEntry)] then
					task.spawn(onRemoved, oldEntry)
				end
			end

			oldEntries = newEntries

			task.wait(1)
		end
	end)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for removed entries.

	### Example
	```lua
	pathfs.watchEntryRemoved("path/to/dir", function(removedEntry)
		print("Removed entry:", removedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onRemoved -- The callback function to call when an entry is removed.
]=]
function pathfs.watchEntryRemoved(
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchEntryRemoved is deprecated and will be removed in future releases")

	return watchEntryRemoved(pathfs.getEntries, directory, onRemoved)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for removed descendant entries.

	### Example
	```lua
	pathfs.watchDescendantEntryRemoved("path/to/dir", function(removedEntry)
		print("Removed entry:", removedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onRemoved -- The callback function to call when an entry is removed.
]=]
function pathfs.watchDescendantEntryRemoved(
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryRemoved is deprecated and will be removed in future releases")

	return watchEntryRemoved(pathfs.getDescendantEntries, directory, onRemoved)
end

local FileOrAsPathType = gt.build(gt.union(
	gt.custom(FilePath.is, "FilePath"),
	AsPathType:type()
))

local function fileOrAsPathToPath(fileOrPath: typeof(FileOrAsPathType:type())): Path
	return createPath(if FilePath.is(fileOrPath) then (fileOrPath :: FilePath).path else fileOrPath :: AsPath)
end

--[=[
	@within pathfs

	Write a file, creating parent directories if they do not exist.

	### Example
	```lua
	pathfs.writeFileAll("path/to/file", "content")
	```

	@param fileOrPath -- The file or path to write to, of type FilePath or AsPathType.
	@param contents -- The contents to write to the file, of type string or table.
]=]
function pathfs.writeFileAll(fileOrPath: typeof(FileOrAsPathType:type()), contents: typeof(ContentsType:type()))
	assert(FileOrAsPathType(fileOrPath))
	assert(ContentsType(contents))

	-- selene: allow(shadowing)
	local path = fileOrAsPathToPath(fileOrPath)
	local parent = path:parent()
	if parent then
		fs.writeDir(parent)
	end
	fs.writeFile(path, contents)
end

type ObserveState = "__inflight__" | "__dead__"
type EntryValue = {
	stateOrCleanup: ObserveState | (() -> ())?,
	entry: DirEntry,
}

local function observeEntry(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry },
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry) -> (() -> ())?)
): () -> ()
	assert(directoryType(directory))
	assert(callbackType(callback))

	local entryValues: {
		[string]: EntryValue?,
	} = {}
	local disconnected = false
	local function attemptStartup(entryValue: EntryValue)
		entryValue.stateOrCleanup = "__inflight__"

		task.defer(function()
			if entryValue.stateOrCleanup ~= "__inflight__" then
				return
			end

			local success, errOrCleanup = pcall(function()
				local cleanup = callback(entryValue.entry)
				if cleanup ~= nil and type(cleanup) ~= "function" then
					error("observeDescendantEntry's callback must return a cleanup function or nil")
				end
				return cleanup
			end)

			if not success then
				print(`Error in observeDescendantEntry callback:\n\t{errOrCleanup}`)
				return
			end

			if entryValue.stateOrCleanup == "__inflight__" then
				entryValue.stateOrCleanup = errOrCleanup
			elseif type(errOrCleanup) == "function" then
				task.spawn(errOrCleanup)
			end
		end)
	end

	local function attemptCleanup(entryValue: EntryValue)
		local cleanup = entryValue.stateOrCleanup
		entryValue.stateOrCleanup = "__dead__"
		if type(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	local function onAdded(entry: DirEntry)
		if disconnected then
			return
		end
		local hash = hashDirEntry(entry)
		if entryValues[hash] then
			return
		end

		local entryValue = {
			stateOrCleanup = "__dead__" :: "__dead__",
			entry = entry,
		}
		entryValues[hash] = entryValue

		attemptStartup(entryValue)
	end

	local function onRemoved(entry: DirEntry)
		local hash = hashDirEntry(entry)
		local entryValue = entryValues[hash]
		if not entryValue then
			return
		end

		attemptCleanup(entryValue)
		entryValues[hash] = nil
	end

	local addedWatchingThread = watchEntryAdded(getEntries, directory, onAdded)
	local removedWatchingThread = watchEntryRemoved(getEntries, directory, onRemoved)

	task.defer(function()
		if disconnected then
			return
		end
		for _, entry in getEntries(directory) do
			task.spawn(onAdded, entry)
		end
	end)

	return function()
		disconnected = true
		task.cancel(addedWatchingThread)
		task.cancel(removedWatchingThread)
		local value
		do
			local _, newValue = next(entryValues)
			value = newValue
		end
		while value do
			onRemoved(value.entry)
			local _, newValue = next(entryValues)
			value = newValue
		end
	end
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Observe a directory for changes.

	### Example
	```lua
	pathfs.observeEntry("path/to/dir", function(entry)
		print("Entry changed:", entry.name)

		return function()
			print("Entry cleanup:", entry.name)
		end
	end)
	```

	@param directory -- The directory to observe, of type Directory or AsPathType.
	@param callback -- The callback function to call when an entry is added or removed.
]=]
function pathfs.observeEntry(
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry) -> (() -> ())?)
): () -> ()
	-- selene: allow(undefined_variable)
	warn("pathfs.observeEntry is deprecated and will be removed in future releases")

	return observeEntry(pathfs.getEntries, directory, callback)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Observe a directory for changes in its descendants.

	### Example
	```lua
	pathfs.observeDescendantEntry("path/to/dir", function(entry)
		print("Descendant entry changed:", entry.name)

		return function()
			print("Cleanup for entry:", entry.name)
		end
	end)
	```

	@param directory -- The directory to observe, of type Directory or AsPathType.
	@param callback -- The callback function to call when an entry is added or removed.
]=]
function pathfs.observeDescendantEntry(
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry) -> (() -> ())?)
): () -> ()
	-- selene: allow(undefined_variable)
	warn("pathfs.observeDescendantEntry is deprecated and will be removed in future releases")

	return observeEntry(pathfs.getDescendantEntries, directory, callback)
end

--[=[
	@within pathfs

	Serializes a value to a file based on the file extension.
	Supports JSON (.json), TOML (.toml), and YAML (.yaml, .yml) formats.

	### Example
	```lua
	local data = { name = "example", value = 42 }
	pathfs.serializeFile(data, "config.json")
	pathfs.serializeFile(data, "config.toml")
	pathfs.serializeFile(data, "config.yaml")
	```

	@param value -- The value to serialize
	@param fileOrPath -- The file path or FilePath object
]=]
function pathfs.serializeFile(value: any, fileOrPath: typeof(FileOrAsPathType:type()))
	assert(FileOrAsPathType(fileOrPath))

	local path = fileOrAsPathToPath(fileOrPath)
	local extension = string.lower(path:extension() or "")

	local content: string
	if extension == "json" then
		content = serde.encode("json", value)
	elseif extension == "toml" then
		content = serde.encode("toml", value)
	elseif extension == "yaml" or extension == "yml" then
		content = serde.encode("yaml", value)
	else
		error(`Unsupported file format: {extension}. Supported formats are: json, toml, yaml, yml`)
	end

	fs.writeFile(path, content)
end

--[=[
	@within pathfs

	Deserializes a file based on the file extension.
	Supports JSON (.json), TOML (.toml), and YAML (.yaml, .yml) formats.

	### Example
	```lua
	local config = pathfs.deserializeFile("config.json")
	local settings = pathfs.deserializeFile("settings.toml")
	local data = pathfs.deserializeFile("data.yaml")
	```

	@param fileOrPath -- The file path or FilePath object
	@return any -- The deserialized value
]=]
function pathfs.deserializeFile(fileOrPath: typeof(FileOrAsPathType:type())): any
	assert(FileOrAsPathType(fileOrPath))

	local path = fileOrAsPathToPath(fileOrPath)

	if not fs.isFile(path) then
		error(`File does not exist: {path}`)
	end

	local content = fs.readFile(path)
	local extension = string.lower(path:extension() or "")

	if extension == "json" then
		return serde.decode("json", content)
	elseif extension == "toml" then
		return serde.decode("toml", content)
	elseif extension == "yaml" or extension == "yml" then
		return serde.decode("yaml", content)
	else
		error(`Unsupported file format: {extension}. Supported formats are: json, toml, yaml, yml`)
	end
end

return pathfs
