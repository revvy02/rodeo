-- rodeo — typed standard library for Roblox Studio scripts.
--
-- Usage:
--   local rodeo = require("@rodeo")        -- typed access to fs, io, process, stream, roblox
--   local fs = require("@rodeo/fs")        -- typed sub-module access
--
-- Each module's wrapper functions live in its own file (fs.luau, io.luau,
-- etc.); shared types (StreamHandle, ProcessResult, ...) live in
-- `_internal/types.luau`. The _G.__rodeo_eid per-execution dispatch is in
-- `_internal/singleton.luau`.
--
-- NOTE: runtime behavior is implemented in rodeo-pkg/shims/, which is what
-- the plugin embeds and executes. This file is typedef-only — it's what
-- `rodeo setup` writes into `~/.rodeo/typedefs/<version>/` for the IDE.

-- Underscore-prefix on these locals: they're only referenced via `typeof()`
-- to derive the type aliases below. Selene flags `local x = require(...); ...
-- typeof(x)` as unused because type-level use doesn't count as runtime use.
local _fs = require("./fs")
local _io = require("./io")
local _process = require("./process")
local _stream = require("./stream")
local _roblox = require("./roblox")

local singleton = require("./_internal/singleton")
local shared = require("./types")

-- Derive per-module types from the modules themselves (single source of truth).
export type Fs = typeof(_fs)
export type Io = typeof(_io)
export type Process = typeof(_process)
export type Stream = typeof(_stream)
export type Roblox = typeof(_roblox)

-- Re-export shared types so consumers can use `rodeo.StreamHandle` etc.
export type StreamHandle = shared.StreamHandle
export type ProcessHandle = shared.ProcessHandle
export type FileMetadata = shared.FileMetadata
export type DirectoryEntry = shared.DirectoryEntry
export type ProcessResult = shared.ProcessResult
export type StdioKind = shared.StdioKind
export type ProcessRunOptions = shared.ProcessRunOptions

-- Composite type spanning the whole runtime surface.
export type Rodeo = {
	fs: Fs,
	io: Io,
	process: Process,
	stream: Stream,
	roblox: Roblox,
}

return (singleton :: any) :: Rodeo
