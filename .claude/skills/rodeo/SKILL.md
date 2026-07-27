---
name: rodeo
description: CLI tool for Roblox Studio that lets you create studio instances, and run code in any studio environment. Includes commands, flags, DOM targeting, directives, return values, and @rodeo APIs. Use when writing rodeo commands, scripts, or working with Roblox Studio.
---

# rodeo

CLI that executes Luau code inside Roblox Studio via WebSocket. Studio is the runtime, and rodeo connects to it, sends scripts, and streams output back. It's designed to be used like a conventional language runtime.

## Quick start

```bash
rodeo run --place --source "return 1"   # open a fresh place, run, close it
rodeo run script.luau                   # file execution (against a running serve)
rodeo run myscript                      # shorthand for .rodeo/myscript.luau
rodeo run - < script.luau               # stdin
rodeo serve                             # optional: persistent server (no Studio launch)
rodeo state                             # canonical state: studios, DOMs, runs
rodeo kill <id>                         # kill a run OR close a studio by id (from rodeo state)
rodeo save <studio-id>                  # save a studio's place back to its source file
```

`rodeo run --place` is sufficient to spawn a studio with an empty place. The studio process is attached to that run process, and will terminate if that run process gets terminated. You can do `rodeo run --place --detach` to ensure that studio instance persists even if that run process is ended.

## Commands

### `rodeo serve`

Start a persistent server. Does NOT launch Studio — use `run --place` for that.

- `--port <n>` — port number (default: 44872)
- `--master` / `--studio` / `--master-host` / `--master-port` — process-split internals; rarely needed directly
- `--ppid <pid>` — exit when this process dies

### `rodeo run`

Run a script in Studio.

- `<script>` — path to script, or `-` for stdin. Any name without a `.` resolves to `.rodeo/<name>.luau` when that file exists — nested paths included (`rodeo run tests/smoke` → `.rodeo/tests/smoke.luau`)
- `-s` / `--source <code>` — execute inline source code
- `--mode edit|run|test|play` — Studio mode (auto-transitions; the only flag that does). Defaults to edit; never inferred from --context/--dom, so a server/client run must pass --mode
- `--context plugin|server|client|elevated` — the identity level to run at (its own Luau VM on the DOM): plugin, server-runtime identity, client-runtime identity, or command bar. Not a script class
- `--dom edit|server|client` — which DOM (usually inferred); `edit` targets the edit DOM even while a test/play session runs
- `--studio-id <id>` — scope routing to one studio (id from `rodeo state`; unique prefix ok)
- `--dom-id <id>` — pin the run to one DOM (id from `rodeo state`; unique prefix ok). Only `--context` may accompany it
- `--show-return` — print return value to stdout (any size; streamed in chunks)
- `--return <path>` — write return value to file: `.luau`/`.lua` emits Luau source, anything else JSON. Size-unbounded — the value lives in the file and is NOT also returned in-wire.
- `--output <path>` — write execution output (prints/logs) to file
- `--cache-requires` — use cached module state (see below)
- `--place [<value>]` — launch Studio: empty (no value), a place ID (number), or a file path (`.rbxl`/`.rbxlx`). Guarantees a fresh place even if a serve already has one open; the run is pinned to it and it closes after the run (unless `--detach`).
- `--place.universe <id>` — universe ID (auto-resolved from place ID if omitted)
- `--detach` — keep Studio running after rodeo exits
- `--focus` — bring Studio to foreground on launch (default: background)
- `--show-widgets <spec>` — allow-list of Studio dock widgets to keep; everything else (panels, ribbon, command bar) is hidden. `none` hides all; a comma list keeps those (aliases: output, explorer, properties, editor, toolbox, assistant, ribbon, commandbar; or a raw panel ID). Restored on exit
- `--save [path]` — save the place after the run through the verified save path (retried until the file's mtime changes; a missed save is a nonzero exit, never silent). Bare `--save` opens the source file directly and saves into it; `--save <path>` saves to that path. With `--detach`, saves at run end and leaves Studio open
- `--profile [dir]` — enable microprofiler auto-capture and collect dumps (optional output directory)
- `--sourcemap <path>` — path to sourcemap.json for instance resolution
- `--host <host>` / `--port <port>` — server address (default: localhost:44872)
- `--no-output` — suppress all output
- `--no-print` / `--no-warn` / `--no-error` / `--no-info` — suppress specific log levels
- `--fflag.override <KEY=VALUE>` (repeatable) / `--fflag.file <path>` — FFlag overrides at launch
- `--ppid <pid>` — exit when this process dies
- `-- arg1 arg2` — script arguments (access via `require("@rodeo/process").args`)

### `rodeo state` / `rodeo kill <id>` / `rodeo save [id]`

`rodeo state` prints the canonical state as flat tables joined by the short
(8-char) studio id. Studios are split by origin — LOCAL (file launches, with
the source file the launch asked for and the working file Studio actually has
open) and UPLOADED (place-id launches) — followed by DOMS (one row per DOM,
with the player for client DOMs) and RUNS (each run joined to the DOM/studio
it executes on). Empty sections keep their header with a `-` placeholder row:

```
LOCAL
 ID        MODE  SOURCE_PATH      WORKING_PATH                    STATUS
 68298c7b  edit  ./MyGame.rbxl    .rodeo/.temp/rodeo-<uuid>.rbxl  connected

UPLOADED
 ID        MODE  PLACE           STATUS
 9aec44bb  test  Place1 (12345)  connected

DOMS
 ID        KIND    STUDIO    USER
 2a32ef67  edit    9aec44bb  -
 f37d718d  server  9aec44bb  -
 b8f11a11  client  9aec44bb  revvy02 (902015375)

RUNS
 ID            STATE    MODE  KIND    CONTEXT  DOM       STUDIO
 b0ec4d9a103b  running  test  client  client   b8f11a11  9aec44bb
```

`--json` emits the full snapshot (including `sourcePath`/`workingPath`).

`rodeo kill <id>` takes a run id or a studio id (unique prefixes ok) and
resolves which kind it names: a run match kills the run, a studio match closes
that Studio (detached ones included; its active runs fail as disconnected).
Ids change each launch, so read them from `rodeo state` rather than storing
them.

`rodeo save [studio-id] [--out <path>]` saves a studio's place. Targets the
only connected Studio when the id is omitted; errors listing candidates when
several are connected. The save is verified (retried until the working file's
mtime changes), then committed: to `--out` when given, otherwise back to the
launch's SOURCE_PATH — so the default persists the live place into the file
you opened. Blank-place studios with no `--out` just save their working file.
Manually-opened Studios can't be saved this way (no rodeo session).

## Directives

A single-line comment that pre-fills `rodeo run` flags — full parity with the CLI, so scripts declare their own runtime configuration:

```luau
-- @rodeo run --place ./game.rbxl --mode test --context client --save -- --user frank

local process = require("@rodeo/process")
print(process.args)  --> { "--user", "frank" }
```

Then just `rodeo run my-script.luau` — no flags at the call site. Everything after `--` becomes `process.args`.

The directive is the base configuration; the CLI overrides it per layer: a flag passed on the CLI replaces the directive's copy of that flag (repeatable flags like `--fflag.override` accumulate instead), and a CLI `--` tail replaces the directive's script args wholesale.

## DOM Targeting: --mode / --context / --dom

Three orthogonal flags, all optional with sensible defaults. `--mode` picks the
Studio mode, `--dom` which DataModel to run on, and `--context` the identity
level to run at.

- **mode** — `edit`, `run`, `test`, `play`
- **dom** — `edit`, `server`, `client`. Which DataModel. The edit DOM exists in
  every mode, so `--dom edit` targets it even while a test/play session runs,
  without disturbing the session. The DOM is the **communication boundary**:
  code on the same DOM shares instances (BindableEvents); different DOMs talk
  via RemoteEvents.
- **context** — the **identity level**, not a script class:
  - `plugin` — plugin identity
  - `server` — the identity server-side code runs at when the game is running
  - `client` — the identity client-side code runs at when running (LocalScripts / `RunContext = Client`)
  - `elevated` — command-bar identity (via StudioMCP), for privileged APIs

  Each context is an **independent Luau VM** on the DOM — separate global state,
  so contexts can't touch each other's Luau values directly (they coordinate
  through DOM instances). A ModuleScript has no fixed context: it runs at
  whatever context `require`s it.

Defaults: `mode` defaults to **edit** and is **never inferred** from `--context`/
`--dom`, so a server/client run needs `--mode` (`--context server` alone resolves
to edit+server and errors). `context` alone implies its DOM; `mode` alone → the
mode's primary DOM at its native context.

### Common combinations

Read each row as (studio mode, which DOM, at which identity):

| Flags | Runs |
|-------|------|
| *(none)* | edit DOM, plugin identity (default) |
| `--context elevated` | edit DOM, command-bar identity |
| `--mode run --context server` | run mode, server DOM, server identity |
| `--mode test --context server` | play test, server DOM, server identity |
| `--mode test --context client` | play test, client DOM, client identity |
| `--mode test --context plugin` | play test, server DOM, plugin identity |
| `--mode test --dom client --context plugin` | play test, client DOM, plugin identity |
| `--dom edit` | edit DOM, plugin identity — even while a test/play session runs (session preserved) |
| `--mode play --context server` | multiplayer test, server DOM, server identity |
| `--mode play --dom client` | multiplayer test, client DOM, client identity (starts one client; appends one more against a running session) |

Any combination that isn't a valid (mode, dom, context) triple errors at
submit — including a server/client `--context`/`--dom` with no `--mode` (mode
defaults to edit, and edit has only an edit DOM).

### Studio modes (derived from connected DOMs)

| Mode | DOMs |
|------|-----|
| Edit | Edit DOM only |
| Run | Edit + server (F8) |
| Test | Edit + server + client (F5) |
| Play | Edit + server + N clients via `StudioTestService:ExecuteMultiplayerTestAsync` (one Studio; the engine caps multiplayer-test clients at 8) |

## `--cache-requires`

When passed, the script gets access to the global module state for the context it's in. Useful for debugging — you can inspect loaded modules, shared state, etc.

Without it, rodeo uses an uncacheable require traversal (module cloning) so each execution gets fresh module state — good for testing, since stale cached modules can silently run old code.

## `@rodeo` API

Run `rodeo setup` once per project to generate types and `.luaurc`.

```lua
local rodeo = require("@rodeo")         -- full API
local fs = require("@rodeo/fs")         -- individual modules
local process = require("@rodeo/process")
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")
local roblox = require("@rodeo/roblox")
```

### `@rodeo/fs` — file system (host-side, run-client cwd)

```lua
fs.exists(path) -> boolean
fs.stat(path) -> FileMetadata
fs.type(path) -> string
fs.open(path, mode?) -> StreamHandle
fs.remove(path)
fs.mkdir(path)
fs.rmdir(path)
fs.copy(src, dest)
fs.listdir(path) -> { DirectoryEntry }
```

### `@rodeo/process` — system processes

```lua
process.args        -- script arguments (from -- arg1 arg2)
process.env         -- environment variables
process.cwd()       -- current working directory
process.homedir()   -- home directory
process.execpath()  -- path to rodeo executable
process.exit(code)

-- Blocking execution
process.run(args, options?) -> ProcessResult
process.system(command, options?) -> ProcessResult

-- Async execution with stdio piping
process.create(args, options?) -> ProcessHandle
process.kill(handle)
```

### `@rodeo/io` — stdin/stdout/stderr

```lua
io.stdin   -- StreamHandle
io.stdout  -- StreamHandle
io.stderr  -- StreamHandle
io.read()  -- read line from stdin
```

### `@rodeo/stream` — stream operations

```lua
stream.read(handle) -> string?        -- text; one-shot (~16MiB cap on files — use readBytes for big files)
stream.write(handle, data)            -- chunked automatically; any size is safe
stream.readBytes(handle) -> buffer    -- chunked automatically; any size is safe
stream.writeBytes(handle, data: buffer) -- chunked automatically; any size is safe
stream.close(handle)
```

### `@rodeo/roblox` — model import/export

```lua
roblox.import(path) -> { Instance }      -- load .rbxm/.rbxmx as Instances
roblox.export(path, { instances })       -- write Instances to .rbxm/.rbxmx/.rbxl/.rbxlx
roblox.capture(output?, options?) -> string  -- screenshot Studio, returns absolute path
```

Import/export stream through the transport in chunks and write atomically —
arbitrarily large models are fine. XML output is picked by extension.

`capture`'s `output` is an exact file path when it ends in `.png`, otherwise a
directory for the auto-named file (default `.rodeo-screenshots/`). `options`
(all optional): `cframe` (scripted camera for the shot, restored after),
`fov`, `focus`, `settle` (seconds to wait before capturing). Needs a viewport
— plugin context, or client context in a running session (server context
errors). macOS only.

## Common patterns

```bash
# One-shot in a fresh place
rodeo run --place --show-return --source "return game.Workspace:GetChildren()"

# Against a published place
rodeo run --place 1234567890 --source "print(game.PlaceId)"

# Big data out of Studio (size-unbounded)
rodeo run --return dump.luau --source "return game.Workspace:GetDescendants()"
rodeo run --return data.json --source "return bigTable"

# Script arguments
rodeo run script.luau -- arg1 arg2
# In script: local args = require("@rodeo/process").args

# Multiplayer test: create the session with its client(s) up front, then run on the server.
# (Client-first matters on Studio 0.726–0.729: growing a running session crashes — see Gotchas.)
rodeo run --place --mode play --dom client --show-return --source "return game.Players.LocalPlayer.UserId"
rodeo run --mode play --context server --source "print(#game.Players:GetPlayers())"

# Profiling
rodeo run --place --profile ./profiles --mode play --context server perf-script.luau

# Suppress logs
rodeo run --no-output script.luau    # suppress all
rodeo run --no-print script.luau     # suppress print() only

# .rodeo/ shorthand
rodeo run myscript                   # runs .rodeo/myscript.luau

# Work against a local place, then persist it
rodeo run --place MyGame.rbxl --detach --source "..."  # edits land in a temp copy
rodeo save <studio-id>                                 # commit the copy back to MyGame.rbxl
rodeo kill <studio-id>                                 # close the Studio
```

## Gotchas

- `--mode run|test|play` when the studio isn't already in that mode → auto-transitions (may take a few seconds)
- `--context elevated` requires Studio's AI assistant / StudioMCP to be available — rodeo bridges to elevated identity through it
- **`test`/`play` modes (and `--context elevated`) can hang ~60s and time out if the Studio never connected to StudioMCP** — the Assistant plugin only opens its MCP socket when the Assistant panel is opened, and `mcp-server.enabled=true` alone doesn't guarantee it (github.com/revvy02/rodeo issue #4). Symptom: `rodeo state` shows the studio stuck in `play` mode with the run `queued`. Recovery: open the AI Assistant panel in that Studio — the run dispatches within seconds
- **Never grow a running play session on Studio 0.726–0.729** — `StudioTestService:AddPlayers` SIGSEGVs the play-server process ~0.6s in (engine bug, reproduced with zero rodeo code). A fresh `--mode play` test spawns its one client up front via `ExecuteMultiplayerTestAsync` (fine); appending another (`--mode play --dom client` against an already-running session, which calls `AddPlayers`) crashes it. `EndTest` also silently no-ops on 0.729. This is why the isolatedPlay/playProfiling suites can have known failures on these versions
- `rodeo setup` must be run once per project for `@rodeo/*` imports
- Return values >2MiB without a `--return` file fail the run by design — pass a file path for big payloads
- `--place` always opens its own fresh place, even when another place is already open on the serve — runs never silently land in a resident place
- **`--place file.rbxl` without `--save` opens a temp COPY** (the WORKING_PATH in `rodeo state`) — in-Studio edits and manual Cmd+S land in the copy, which is deleted when the Studio closes. Persist with `rodeo save <studio-id>` (commits back to SOURCE_PATH) before closing, or launch with `--save` to open the source directly
- `stream.read` on a file handle is a one-shot read (~16MiB transport cap) — an oversized read fails that call with a size error (the run survives); use `fs.open` + `stream.readBytes` for big files, which chunks any size
- A killed/disconnected run exits 2 with `rodeo: run disconnected: <reason>` on stderr; an explicit `rodeo kill` exits 1
