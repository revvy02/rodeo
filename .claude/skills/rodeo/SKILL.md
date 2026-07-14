---
name: rodeo
description: Rodeo CLI reference — commands, flags, DOM targeting, directives, return values, and @rodeo APIs. Use when writing rodeo commands, scripts, or working with Studio execution.
---

# rodeo

CLI that executes Luau code inside Roblox Studio via WebSocket. Studio is the runtime — rodeo connects to it, sends scripts, and streams output back. macOS and Windows are fully supported.

## Quick start

```bash
rodeo run --place --source "return 1"   # open a fresh place, run, close it
rodeo run script.luau                   # file execution (against a running serve)
rodeo run myscript                      # shorthand for .rodeo/myscript.luau
rodeo run - < script.luau               # stdin
rodeo serve                             # optional: persistent server (no Studio launch)
rodeo state                             # canonical state: studios, DOMs, runs
rodeo kill <id>                         # kill a run by its id (from rodeo state)
```

`rodeo run --place` is self-sufficient: it bootstraps a serve if none is running, opens the place, pins the run to it, and closes it afterward. A persistent `rodeo serve` is only needed when you want a long-lived Studio that multiple `rodeo run` calls share.

## Global flags

- `-v` / `--verbose` — enable debug output. Also available via `RODEO_VERBOSE=1` env var.
  Note: `rodeo run --verbose` makes only the run client verbose; backend logs (routing,
  reconciliation, MCP) come from the serve — run `RODEO_VERBOSE=1 rodeo serve` to see them.
  `RODEO_STUDIOMCP_VERBOSE=1` on the serve additionally runs the spawned StudioMCP with `-v`.

## Commands

### `rodeo serve`

Start a persistent server. Does NOT launch Studio — use `run --place` for that.

- `--port <n>` — port number (default: 44872)
- `--master` / `--studio` / `--master-host` / `--master-port` — process-split internals (master orchestrator vs studio backend); rarely needed directly
- `--ppid <pid>` — exit when this process dies

### `rodeo run`

Run a script in Studio.

- `<script>` — path to script, or `-` for stdin. Simple names (no path separator, no extension) resolve to `.rodeo/<name>.luau` when that file exists
- `-s` / `--source <code>` — execute inline source code
- `--mode edit|run|test|play` — Studio mode (auto-transitions). Defaults from --context/--dom, else edit
- `--context plugin|server|client|elevated` — run context (cf. Roblox `Script.RunContext`); `elevated` = command bar
- `--dom edit|server|client` — which DOM (usually inferred); `edit` targets the edit DOM even while a test/play session runs
- `--clients <n>` — play-test session size (mode play): ensure N clients total
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
- `--no-hud` — strip Studio UI panels (Explorer/Properties/Toolbox/etc.) for a minimal launch; restored on exit
- `--save [path]` — save Studio place on exit, optionally to a specific path
- `--profile [dir]` — enable microprofiler auto-capture and collect dumps (optional output directory)
- `--sourcemap <path>` — path to sourcemap.json for instance resolution
- `--host <host>` / `--port <port>` — server address (default: localhost:44872)
- `--no-output` — suppress all output
- `--no-print` / `--no-warn` / `--no-error` / `--no-info` — suppress specific log levels
- `--fflag.override <KEY=VALUE>` (repeatable) / `--fflag.file <path>` — FFlag overrides at launch
- `--ppid <pid>` — exit when this process dies
- `-- arg1 arg2` — script arguments (access via `require("@rodeo/process").args`)

### `rodeo state` / `rodeo kill <id>`

`rodeo state` prints the canonical state as three flat tables joined by the
short (8-char) studio id — STUDIOS (studio-level facts), DOMS (one row per
DOM, linked to its studio, with the player for client DOMs), and RUNS (each
run joined to the DOM/studio it executes on, with its resolved route and
context):

```
STUDIOS
 STUDIO    MODE  PLACE           STATUS
 9aec44bb  test  Place1 (12345)  connected

DOMS
 DOM       KIND    STUDIO    USER
 2a32ef67  edit    9aec44bb  -
 f37d718d  server  9aec44bb  -
 b8f11a11  client  9aec44bb  revvy02 (902015375)

RUNS
 ID            STATE    MODE  KIND    CONTEXT  DOM       STUDIO
 b0ec4d9a103b  running  test  client  client   b8f11a11  9aec44bb
```

Studio identity: `studioId` is the canonical id you address by — plugin-minted,
one per Studio process, present for both rodeo-launched and manually-launched
studios. It's minted fresh each time a Studio process starts (never persisted
into place files), so don't store it across restarts — re-read it from
`rodeo state`. `sessionId` is the launch token, present only for studios rodeo
launched (so its presence = "rodeo owns this / can close it"). `--studio-id`
and `--dom-id` both accept a unique prefix of these ids.

Every run has one identity: a short master-minted run id (12 hex chars),
shown by `state` and accepted by `kill`. The same id tags the run's log
lines. Both take `--host` / `--port`.

### `rodeo save`

Save the Studio place file.

- `--out <path>` — copy saved file to this path

### `rodeo setup`

Generate type definitions and configure `.luaurc` for `@rodeo/*` resolution. Run once per project.

### `rodeo plugin`

Build and install the rodeo plugin into Studio's plugins directory (manual installs; `run --place` injects its own per-launch plugin automatically).

## Directives

A single-line comment that pre-fills `rodeo run` flags — full parity with the CLI, so scripts declare their own runtime configuration:

```luau
-- @rodeo run --place ./game.rbxl --context client --save -- --user frank

local process = require("@rodeo/process")
print(process.args)  --> { "--user", "frank" }
```

Then just `rodeo run my-script.luau` — no flags at the call site. Everything after `--` becomes `process.args`.

## DOM Targeting: --mode / --context / --dom

Three orthogonal flags, all optional with sensible defaults. `--mode` picks the
Studio mode, `--context` the run context (cf. Roblox `Script.RunContext`), and
`--dom` which DataModel — usually inferred from the other two.

- **mode** — `edit`, `run`, `test`, `play`
- **context** — `plugin` (ModuleScript), `server` (Script), `client` (LocalScript), `elevated` (command bar via StudioMCP)
- **dom** — `edit`, `server`, `client`. The edit DOM exists in every mode (it's
  the source the run/test/play DOMs are cloned from), so `--dom edit` targets it
  even while a test/play session runs — without disturbing the session.

Defaults: bare = edit + plugin. `context` alone implies a mode (client→test,
server→run, plugin/elevated→edit) and its DOM. `mode` alone → the mode's primary
DOM with its native context.

### Common combinations

| Flags | Runs as |
|-------|---------|
| *(none)* | Edit mode, ModuleScript (default) |
| `--context elevated` | Edit mode, elevated (command bar) |
| `--context server` | Run mode (F8), server Script |
| `--mode test --context server` | Play test (F5), server Script |
| `--context client` | Play test, client LocalScript |
| `--mode test --context plugin` | Play test, server DOM as ModuleScript |
| `--mode test --dom client --context plugin` | Play test, client DOM as ModuleScript |
| `--dom edit` | Edit DOM, ModuleScript — even while a test/play session runs (session preserved) |
| `--mode play --context server` | Multiplayer test, server |
| `--mode play --dom client` | Multiplayer test, +1 client, run on a client |
| `--mode play --dom client --clients <n>` | Multiplayer test sized to `n` clients (spawned up front at session start; growing an existing session crashes on Studio 0.726–0.729 — see Gotchas) |

Any combination that isn't a valid (mode, dom, context) triple errors at
submit (e.g. `--mode edit --dom server` — edit mode has only an edit DOM).

### Studio modes (derived from connected DOMs)

| Mode | DOMs |
|------|-----|
| Edit | Edit DOM only |
| Run | Edit + server (F8) |
| Test | Edit + server + client (F5) |
| Play | Edit + server + N clients via `StudioTestService:ExecuteMultiplayerTestAsync` (one Studio; the engine caps multiplayer-test clients at 8) |

### Auto-transitions

Rodeo auto-transitions Studio between modes when needed. If you pass `--context
server` but Studio is in edit mode, rodeo enters run mode automatically; wrong
mode active → exits first then enters the correct one. `--mode play` starts a
multiplayer test session. No manual mode management needed.

### `--studio-id` / `--dom-id`

`--studio-id <id>` scopes routing to one studio instance by its canonical
`studioId` (from `rodeo state`; unique prefix ok) — useful when multiple Studios
are open. Works for rodeo-launched and manually-launched studios alike (the
`studioId` is plugin-minted, not the launch session). `--dom-id <id>` skips
routing entirely and pins to one DOM; only `--context` may accompany it (e.g.
`--dom-id <id> --context elevated` — a pin + context, previously inexpressible).

## Return values

- In-wire returns (no `--return` file) are capped at **2MiB of JSON** — bigger values fail the run with an actionable error.
- `--return <path>` is the size-unbounded path (streamed in 4MB chunks). The value lives in the file; programmatic `result.return` is empty in that case.
- `--show-return` prints any size to stdout; combined with a too-big in-wire value it prints in full and just omits the wire copy (warning on stderr).

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
stream.read(handle) -> string?
stream.write(handle, data)        -- chunked automatically; any size is safe
stream.readBytes(handle) -> buffer
stream.writeBytes(handle, data: buffer)
stream.close(handle)
```

### `@rodeo/roblox` — model import/export

```lua
roblox.import(path) -> { Instance }   -- load .rbxm/.rbxmx as Instances
roblox.export(path, { instances })        -- write Instances to .rbxm/.rbxmx
```

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
rodeo run --place --mode play --dom client --clients 1 --show-return --source "return game.Players.LocalPlayer.UserId"
rodeo run --mode play --context server --source "print(#game.Players:GetPlayers())"

# Profiling
rodeo run --place --profile ./profiles --mode play --context server perf-script.luau

# Suppress logs
rodeo run --no-output script.luau    # suppress all
rodeo run --no-print script.luau     # suppress print() only

# .rodeo/ shorthand
rodeo run myscript                   # runs .rodeo/myscript.luau
```

Multiplayer test sessions (`--mode play`) are driven through `StudioTestService:ExecuteMultiplayerTestAsync` under the hood; `AddPlayers`/`EndTest` on the server DOM grow/end the session (both broken on Studio 0.726–0.729 — see Gotchas).

## Gotchas

- `--context server` / `--context client` / `--mode test` without the right mode active → auto-transitions (may take a few seconds)
- `--context elevated` requires Studio's AI assistant / StudioMCP to be available — rodeo bridges to elevated identity through it
- **`test`/`play` modes (and `--context elevated`) can hang ~60s and time out if the Studio never connected to StudioMCP** — the Assistant plugin only opens its MCP socket when the Assistant panel is opened, and `mcp-server.enabled=true` alone doesn't guarantee it (github.com/revvy02/rodeo issue #4). Symptom: `rodeo state` shows the studio stuck in `play` mode with the run `queued`. Recovery: open the AI Assistant panel in that Studio — the run dispatches within seconds
- **Never grow a running play session on Studio 0.726–0.729** — `StudioTestService:AddPlayers` SIGSEGVs the play-server process ~0.6s in (engine bug, reproduced with zero rodeo code). Size the session up front with `--clients <n>` when it's created; appending (`--mode play --dom client` against an existing session, or a `--clients` value above the current count) crashes it. `EndTest` also silently no-ops on 0.729. This is why the isolatedPlay/playProfiling test suites have known failures on these versions
- `rodeo setup` must be run once per project for `@rodeo/*` imports
- Return values >2MiB without a `--return` file fail the run by design — pass a file path for big payloads
- `--place` always opens its own fresh place, even when another place is already open on the serve — runs never silently land in a resident place
- A killed/disconnected run exits 2 with `rodeo: run disconnected: <reason>` on stderr; an explicit `rodeo kill` exits 1
