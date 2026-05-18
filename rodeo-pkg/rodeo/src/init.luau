-- rodeo — typed standard library for Roblox Studio scripts.
--
-- Usage:
--   local rodeo = require("@rodeo")        -- typed access to fs, io, process, stream, roblox
--   local fs = require("@rodeo/fs")        -- typed sub-module access
--
-- Each module's `export type` declarations live in its own file. The
-- _G.__rodeo_eid per-execution dispatch is in `_internal/singleton.luau`.
--
-- NOTE: runtime behavior is implemented in rodeo-pkg/rodeo/shims/, which is what
-- the plugin embeds and executes. This file is typedef-only — it's what
-- `rodeo setup` writes into `~/.rodeo/typedefs/<version>/` for the IDE.

-- Underscore-prefix on these locals: they're only referenced via `typeof()`
-- and as namespaces for type re-exports. Selene flags `local x = require(...)`
-- as unused if not referenced at runtime; type-level use doesn't count.
local _fs = require("./fs")
local _io = require("./io")
local _process = require("./process")
local _stream = require("./stream")
local _roblox = require("./roblox")

local singleton = require("./_internal/singleton")

-- Per-module type aliases derived from the modules themselves (single source of truth).
export type Fs = typeof(_fs)
export type Io = typeof(_io)
export type Process = typeof(_process)
export type Stream = typeof(_stream)
export type Roblox = typeof(_roblox)

-- Re-export each module's owned types so `rodeo.FileMetadata` etc. resolve.
export type FileMetadata = _fs.FileMetadata
export type DirectoryEntry = _fs.DirectoryEntry
export type StreamHandle = _stream.StreamHandle
export type ProcessHandle = _process.ProcessHandle
export type ProcessResult = _process.ProcessResult
export type StdioKind = _process.StdioKind
export type ProcessRunOptions = _process.ProcessRunOptions

-- Composite type spanning the whole runtime surface.
export type Rodeo = {
	fs: Fs,
	io: Io,
	process: Process,
	stream: Stream,
	roblox: Roblox,
}

return (singleton :: any) :: Rodeo
