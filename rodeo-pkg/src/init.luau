-- rodeo — typed standard library for Roblox Studio scripts.
--
-- Usage:
--   local rodeo = require("@rodeo")        -- typed access to fs, io, process, stream, roblox
--   local fs = require("@rodeo/fs")        -- typed sub-module access
--
-- This file composes the public surface. Each module's `export type` lives
-- next to its shim file (fs.luau, io.luau, etc.); shared types
-- (StreamHandle, ProcessResult, ...) live in `_internal/types.luau`. The
-- _G.__rodeo_eid per-execution dispatch is in `_internal/singleton.luau`.
--
-- NOTE: runtime behavior is implemented in rodeo-pkg/shims/, which is what
-- the plugin embeds and executes. This file is typedef-only — it's what
-- `rodeo setup` writes into `~/.rodeo/typedefs/<version>/` for the IDE.

local fs = require("./fs")
local io = require("./io")
local process = require("./process")
local stream = require("./stream")
local roblox = require("./roblox")

local singleton = require("./_internal/singleton")
local shared = require("./_internal/types")

-- Re-export per-module types so consumers can keep using `rodeo.Fs` etc.
export type Fs = fs.Fs
export type Io = io.Io
export type Process = process.Process
export type Stream = stream.Stream
export type Roblox = roblox.Roblox

-- Re-export shared types.
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
