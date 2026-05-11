# Runtime library (`@rodeo/*`)

Scripts running inside Studio can `require("@rodeo/<module>")` for filesystem, IO, stream, process, and Roblox helpers.

For the CLI that submits these scripts, see [cli.md](cli.md). For driving rodeo from Luau, see [api.md](api.md).

## Setup

Run `rodeo setup` once per project (see [rodeo setup](cli.md#rodeo-setup)). It writes type definitions under `~/.rodeo/typedefs/<version>/` and adds a `rodeo` alias to `.rodeo/.luaurc` so `require("@rodeo")` and `require("@rodeo/<module>")` resolve at bundle time and in your editor.

```luau
local fs     = require("@rodeo/fs")
local io     = require("@rodeo/io")
local stream = require("@rodeo/stream")
local proc   = require("@rodeo/process")
local rbx    = require("@rodeo/roblox")
```

You can also pull all modules at once:

```luau
local rodeo = require("@rodeo")
rodeo.fs.exists("path")
rodeo.process.run({ "echo", "hi" })
```

## `@rodeo/fs` — filesystem

All paths are interpreted relative to rodeo's working directory.

| Function | Signature | Notes |
|---|---|---|
| `fs.open` | `(path: string, mode: string?) -> StreamHandle` | Open for reading (`"r"`, default) or writing (`"w"`). Returns an opaque stream handle — pair with [`@rodeo/stream`](#rodeostream--stream-io). |
| `fs.exists` | `(path: string) -> boolean` | True if a file or directory exists. |
| `fs.type` | `(path: string) -> string` | `"file"` or `"dir"`. |
| `fs.stat` | `(path: string) -> FileMetadata` | Metadata for a file/dir. |
| `fs.mkdir` | `(path: string) -> ()` | Create a directory (parents must exist). |
| `fs.listdir` | `(path: string) -> { DirectoryEntry }` | List entries in a directory. |
| `fs.rmdir` | `(path: string) -> ()` | Remove an empty directory. |
| `fs.remove` | `(path: string) -> ()` | Remove a file. |
| `fs.copy` | `(src: string, dest: string) -> ()` | Copy a file. |

`FileMetadata`:

| Field | Type |
|---|---|
| `type` | `string` (`"file"`, `"dir"`) |
| `size` | `number` (bytes) |
| `createdMillis` | `number?` |
| `modifiedMillis` | `number?` |
| `accessedMillis` | `number?` |

`DirectoryEntry`: `{ name: string, type: string }`.

### Example: write, read, delete

```luau
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")

local f = fs.open("notes.txt", "w")
stream.write(f, "hello fs\n")
stream.close(f)

local f2 = fs.open("notes.txt", "r")
local data = stream.read(f2)
stream.close(f2)

fs.remove("notes.txt")
return data  -- "hello fs\n"
```

## `@rodeo/io` — caller IO

Stream handles for the caller's stdin/stdout/stderr, plus `io.read()` for blocking reads from the caller.

| Field / function | Type | Notes |
|---|---|---|
| `io.stdin` | `StreamHandle` | The caller's stdin. |
| `io.stdout` | `StreamHandle` | The caller's stdout. |
| `io.stderr` | `StreamHandle` | The caller's stderr. |
| `io.read` | `() -> string` | Blocks until the caller sends input. From a terminal, this prompts the user. |

For writes, use `stream.write(io.stdout, data)` from [`@rodeo/stream`](#rodeostream--stream-io).

### Example: bidirectional terminal IO

```luau
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")

stream.write(io.stdout, "What is your name? ")
local name = io.read()

print("Hello, " .. name)             -- via Studio's LogService → caller's stdout
stream.write(io.stderr, "[done]\n")  -- direct to caller's stderr
return { name = name }
```

`print()` and `warn()` continue to work — they're routed through Studio's `LogService` and surface in the caller's terminal alongside `io.stdout` writes.

## `@rodeo/stream` — stream IO

Operations on stream handles — both `fs.open` handles and `io.std*` handles.

| Function | Signature | Notes |
|---|---|---|
| `stream.read` | `(handle: StreamHandle) -> string?` | Read available data. Returns `nil` on EOF. |
| `stream.write` | `(handle: StreamHandle, data: any) -> ()` | Write a string to the handle (other types are stringified). |
| `stream.close` | `(handle: StreamHandle) -> ()` | Close the handle. Always close `fs.open` handles. |

## `@rodeo/process` — subprocesses + environment

Subprocesses run on the host (rodeo's machine), not in Studio.

### Properties

| Field | Type | Notes |
|---|---|---|
| `process.args` | `{ string }` | Script arguments passed via `--` on the CLI or `scriptArgs` on the client. |
| `process.env` | `{ [string]: string? }` | Read-only view of host environment variables. Writes throw. |

### Functions

| Function | Signature | Notes |
|---|---|---|
| `process.cwd` | `() -> string` | rodeo's working directory. |
| `process.homedir` | `() -> string` | The host user's home directory. |
| `process.execpath` | `() -> string` | Path to the running `rodeo` binary. |
| `process.exit` | `(code: number) -> ()` | Exit the script with this code. |
| `process.run` | `(args: { string }, options: ProcessRunOptions?) -> ProcessResult` | Synchronously run a command. |
| `process.run` | `(handle: ProcessHandle, options: ProcessRunOptions?) -> ProcessResult` | Wait on an already-spawned process. |
| `process.system` | `(command: string, options: ProcessRunOptions?) -> ProcessResult` | Synchronously run a shell command. |
| `process.create` | `(args: { string }, options: ProcessRunOptions?) -> ProcessHandle` | Spawn asynchronously; returns a handle with stdio streams. |
| `process.kill` | `(handle: ProcessHandle) -> ()` | Kill a spawned process. |

`ProcessRunOptions`:

| Field | Type | Notes |
|---|---|---|
| `cwd` | `string?` | Working directory for the subprocess. |
| `stdio` | `StdioKind?` | Default for stdin/stdout/stderr if not set individually. |
| `stdin` / `stdout` / `stderr` | `StdioKind?` | Per-stream override. |
| `env` | `{ [string]: string }?` | Environment overrides. |

`StdioKind`: `"default" | "piped" | "inherit" | "none" | "tee"`.

`ProcessResult`:

| Field | Type | Notes |
|---|---|---|
| `ok` | `boolean` | `true` iff `exitcode == 0`. |
| `exitcode` | `number` | Exit code. |
| `out` | `string` | Captured stdout (when piped). |
| `err` | `string` | Captured stderr (when piped). |

`ProcessHandle`: opaque value with `stdin`, `stdout`, `stderr` `StreamHandle` fields, populated when the corresponding stream is `"piped"`.

### Example: synchronous run

```luau
local proc = require("@rodeo/process")
local r = proc.run({ "echo", "hello" })
print(r.ok, r.exitcode, r.out)  -- true  0  "hello\n"
```

### Example: spawn + pipe stdin/stdout

```luau
local proc = require("@rodeo/process")
local stream = require("@rodeo/stream")

local child = proc.create({ "cat" }, { stdio = "piped" })
stream.write(child.stdin, "first\n")
local r1 = stream.read(child.stdout)
stream.close(child.stdin)
proc.kill(child)
return r1
```

### Example: shell command

```luau
local proc = require("@rodeo/process")
local r = proc.system("ls -la | head -5")
return r.out
```

## `@rodeo/roblox` — Roblox helpers

| Function | Signature | Notes |
|---|---|---|
| `roblox.load` | `(path: string) -> { Instance }` | Load instances from a `.rbxm`/`.rbxmx` file. Instances are returned unparented. |

### Example: load a model

```luau
local roblox = require("@rodeo/roblox")

local instances = roblox.load("./models/tree.rbxm")
instances[1].Parent = workspace
```

## Notes

- Filesystem and subprocess calls run on the host (rodeo's machine), not inside Studio's sandbox. Full host privileges regardless of which Studio identity (plugin, server, client, elevated) the script is running under — see [VM targeting](cli.md#vm-targeting).
- Static `require("@rodeo/fs")` works; dynamic require strings won't resolve.
- The `@rodeo` alias is project-scoped (set up by `rodeo setup`). Without it, editor type-checking won't work.
