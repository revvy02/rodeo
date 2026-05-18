-- Filesystem operations available inside Studio scripts.
-- Bundled require: `local fs = require("@rodeo/fs")`.
--
-- NOTE: typedef-only. Runtime lives in rodeo-pkg/rodeo/shims/fs.luau.

local singleton = require("./_internal/singleton")
local stream = require("./stream")
local runtime = require(script.Parent.Parent.Parent.shared.proto.runtime)

--- Metadata for a filesystem entry — size, type, timestamps. Returned by `stat`.
export type FileMetadata = runtime.FsStatResponse

--- Name + type pair returned by `listdir` for each child of a directory.
export type DirectoryEntry = runtime.FsDirEntry

local fs = {}

--- Opens the file at `path` in `mode` (`"r"`, `"w"`, `"a"`, etc.). Returns a
--- stream handle usable with `stream.read`, `stream.write`, `stream.close`.
function fs.open(path: string, mode: string?): stream.StreamHandle
	return (singleton :: any).fs.open(path, mode)
end

--- Removes the file at `path`.
function fs.remove(path: string)
	(singleton :: any).fs.remove(path)
end

--- Returns metadata (size, type, timestamps) for the file or directory at `path`.
function fs.stat(path: string): FileMetadata
	return (singleton :: any).fs.stat(path)
end

--- Returns the type of the entry at `path` as a string — e.g. `"file"`, `"dir"`.
function fs.type(path: string): string
	return (singleton :: any).fs.type(path)
end

--- Creates a directory at `path`.
function fs.mkdir(path: string)
	(singleton :: any).fs.mkdir(path)
end

--- Returns `true` if a file or directory exists at `path`.
function fs.exists(path: string): boolean
	return (singleton :: any).fs.exists(path)
end

--- Copies the file at `src` to `dest`. Overwrites `dest` if it exists.
function fs.copy(src: string, dest: string)
	(singleton :: any).fs.copy(src, dest)
end

--- Returns directory entries (name + type) for the immediate children of `path`.
function fs.listdir(path: string): { DirectoryEntry }
	return (singleton :: any).fs.listdir(path)
end

--- Removes the directory at `path`. Fails if non-empty.
function fs.rmdir(path: string)
	(singleton :: any).fs.rmdir(path)
end

return fs
