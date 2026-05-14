-- Internal: shared types referenced by multiple public module files.
-- Anything used by only one module lives in that module's file.
--
-- The proto-generated types (FileMetadata, DirectoryEntry, ProcessResult)
-- live here so the runtime proto import only happens once.

local runtime = require(script.Parent.Parent.Parent.Parent.shared.proto.runtime)

-- Stream handle (opaque, used by fs.open, io stdio fields, stream.read/write/close)
export type StreamHandle = {
	__handle: string,
}

-- Process handle (opaque, returned by process.create). Lives here rather
-- than process.luau because StreamHandle is in this file and ProcessHandle
-- composes StreamHandles.
export type ProcessHandle = {
	__rodeo_pid: string,
	stdin: StreamHandle?,
	stdout: StreamHandle?,
	stderr: StreamHandle?,
}

-- Proto-derived types reused across modules. The proto import only needs
-- to happen here.
export type FileMetadata = runtime.FsStatResponse
export type DirectoryEntry = runtime.FsDirEntry
export type ProcessResult = runtime.ProcessRunResponse

-- Stdio configuration enum, shared between Process options and (future)
-- Stream tee mode.
export type StdioKind = "default" | "piped" | "inherit" | "none" | "tee"

export type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,
	stdin: StdioKind?,
	stdout: StdioKind?,
	stderr: StdioKind?,
	env: { [string]: string }?,
}

return {}
