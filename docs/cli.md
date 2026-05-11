# CLI reference

The `rodeo` binary is the primary surface. This page is the full reference: every subcommand, every commonly-used flag, and the conceptual material (targeting, directives, return values, etc.) you need to understand them.

If you're just getting started, see the [main README](../README.md) for a quickstart. If you want to drive rodeo from Luau instead of the shell, see [api.md](api.md).

## Process model

Three pieces:

- **`rodeo serve`** — long-running master process. Exposes a local API; doesn't launch Studio itself.
- **rodeo plugin** — a Roblox Studio plugin that connects to the master over WebSocket. One plugin per Studio instance.
- **`rodeo run`** — submits a script for execution. Can also launch Studio for you (`--place`).

### Workflows

**Plugin + serve** — install the plugin once into your Studio, then drive your existing Studio sessions from `rodeo serve`. You keep Studio open with whatever place you're working on, and rodeo connects over WebSocket.

```bash
rodeo plugin           # installs rodeo.rbxm into Studio's Plugins/. One-time.
# Restart Studio (and open whatever place you want to work on).
rodeo serve            # listens on 44872; the plugin auto-connects.
rodeo run script.luau  # submit scripts as often as you like.
```

**One-shot with auto-launch** — launch a fresh Studio for a single run, then clean up:

```bash
rodeo run --place script.luau
rodeo run --place --source 'print("hi")'
```

**Persistent auto-launch** — keep an auto-launched Studio alive across many runs. `rodeo run --place` with no script and no `--source` enters persistent mode: it launches Studio and stays alive until Ctrl-C.

```bash
# Terminal 1: launch Studio on port 44880 (default) and stay alive.
rodeo run --place

# Terminal 2: submit scripts (any number of times).
rodeo run script.luau --port 44880
```

**Programmatic (Luau)** — drive `rodeo serve` from Luau via the [Luau API](api.md). The Luau client launches Studio through the API rather than via a CLI flag.

### Default ports

- `rodeo serve` → `44872`
- `rodeo run --place` (auto-spawned serve) → `44880`

Override with `--port` on either command. Both ports are stable so plugin builds can hard-code them.

## Subcommands

### `rodeo serve`

Start a server (the master). Plugins connect to it; `run` submits to it. **Does not launch Studio** — open Studio yourself (with the rodeo plugin installed via `rodeo plugin`), or use `rodeo run --place` / the [Luau API](api.md) to have rodeo launch it for you.

```bash
rodeo serve                          # default port 44872
rodeo serve --port 9000              # custom port
```

Other flags:

- `--port <PORT>` — listen port. Default: `44872`.
- `--master` / `--studio` — split-mode for distributed setups. See [Process roles](#process-roles).
- `--master-host` / `--master-port` — for `--studio` mode.
- `--ppid <PID>` — exit when the given parent process dies. Used internally for child-process lifecycle.

### `rodeo run`

Execute a script against a running serve, or auto-spawn one with `--place`.

```bash
# Connect to an existing serve.
rodeo run script.luau --port 44872

# All-in-one: auto-launch Studio for this run.
rodeo run --place script.luau
rodeo run --place game.rbxl script.luau          # specific place file
rodeo run --place 72824109308551 --show-return --source 'return game.PlaceId'  # published place ID

# Persistent (no script, no --source): stay alive after launch.
rodeo run --place

# Inline source.
rodeo run --place --source 'return 42' --show-return

# Read from stdin.
echo 'print("hello")' | rodeo run -

# Pass arguments to the script (after `--`).
rodeo run script.luau -- arg1 arg2 "arg with spaces"
```

Flags:

| Flag | Purpose |
|---|---|
| `-s, --source <CODE>` | Inline Luau source instead of a file. |
| `--sourcemap <PATH>` | Rojo sourcemap.json for instance-path resolution and Wally requires. |
| `--target <SPEC>` | Pick which VM runs the script. See [VM targeting](#vm-targeting). |
| `--studio <ID\|active>` | When multiple Studios are connected, route to a specific one. |
| `--show-return` | Print the script's return value to stdout. |
| `--return <PATH>` | Write the return value to a file. See [Return values](#return-values). |
| `--output <PATH>` | Write execution output (prints/logs) to a file instead of stdout. |
| `--no-warn`, `--no-error`, `--no-info`, `--no-print`, `--no-output` | Suppress log levels. See [Log filtering](#log-filtering). |
| `--cache-requires` | Use Roblox's standard module cache (default: bypass for fresh code). See [Module caching](#module-caching). |
| `--ppid <PID>` | Exit when the given parent process dies. |

The launch flags (`--place`, `--save`, `--focus`, `--detached`, `--no-hud`, `--profile`, `--logs`, `--place.universe`, `--fflag.override`, `--fflag.file`) and direct-targeting flags (`--vm`, `--job`, `--backend`) are also available on `run`. See [Launch flags](#launch-flags).

### `rodeo ps`

List active processes (active and recently-completed runs) on a server.

```bash
rodeo ps
rodeo ps --port 44880
```

Output includes process IDs and states (`running`, `done`, etc.). Use the IDs with `rodeo kill`.

### `rodeo kill`

Terminate a running process by ID.

```bash
rodeo kill 1
rodeo kill 2 --port 44880
```

### `rodeo save`

Trigger a Studio save against a running serve.

```bash
rodeo save                       # save in-place
rodeo save --out backup.rbxl     # save and copy to an output path
rodeo save --port 44880          # target a specific server
```

The `--save` flag on `run` controls automatic save behavior on exit:

- **No `--save`** — temp place file is deleted on exit (default).
- **`--save`** — save in-place to the original file.
- **`--save <PATH>`** — save to the given path.

### `rodeo plugin`

Build the rodeo Studio plugin and install it as `rodeo.rbxm` into your local Studio's plugins directory. Used for the [manual workflow](#workflows). After installing, restart Studio.

```bash
rodeo plugin
```

You only need this once. The `--place` flows install per-launch plugins automatically — no `rodeo plugin` needed.

### `rodeo setup`

Generate type definitions for the in-Studio `@rodeo` API and configure `.rodeo/.luaurc` so `require("@rodeo")` resolves correctly in your editor.

```bash
rodeo setup
```

Writes types to `~/.rodeo/typedefs/<version>/` and updates `.rodeo/.luaurc` with a `rodeo` alias pointing there. Run it once per project (or after upgrading rodeo). Required if your scripts use the [`@rodeo/*` runtime library](runtime.md).

### `rodeo mcp`

Start an [MCP](https://modelcontextprotocol.io/) server that exposes rodeo as tools to AI assistants (Claude Code, Cursor, etc.). Bridges rodeo's run/state APIs and Studio's MCP tools (script edit, instance inspection, console output, screen capture, etc.) into a single tool surface.

```bash
rodeo mcp                  # connects to default serve port (44872)
rodeo mcp --port 44880     # connect to a specific serve
```

Wire it into a client by pointing at the `rodeo` binary:

```json
{
  "mcpServers": {
    "rodeo": {
      "command": "bin/rodeo",
      "args": ["mcp"]
    }
  }
}
```

A serve must be running for the MCP server to connect to.

## Launch flags

These are available on `rodeo run` and control how Studio is launched.

| Flag | Purpose |
|---|---|
| `--place [VALUE]` | Launch Studio. Empty = new place. Number = place ID. String = `.rbxl`/`.rbxlx` file path. |
| `--place.universe <ID>` | Universe ID (resolved automatically from a place ID if omitted). |
| `--focus` | Bring Studio to the foreground (default: background). |
| `--detached` | Keep Studio running after rodeo exits. |
| `--no-hud` | Strip Studio UI panels (Explorer/Properties/Toolbox/Output). Restored on exit. |
| `--save [PATH]` | Save place on exit (in-place if no path; otherwise to `PATH`). |
| `--profile [DIR]` | Enable microprofiler auto-capture; collect dumps to `DIR` (or `.rodeo/.temp/profiles/`). |
| `--logs [DIR]` | Collect Studio log output to `DIR` (or `.rodeo/.temp/logs/`). |
| `--fflag.override KEY=VALUE` | Set an FFlag override (repeatable). |
| `--fflag.file <PATH>` | Load FFlag overrides from a JSON file. |

Direct targeting (alternatives to `--target`):

- `--vm <VM_ID>` — target a specific VM directly (IDs come from `rodeo ps` or the API).
- `--job <JOB_ID>` — target a specific game-server instance by `gameInstanceId`.
- `--backend <NAME_OR_ID>` — pick a specific backend device.

### Parallel workers

Spin up multiple Studio instances on different ports for parallel work:

```bash
rodeo run --place --port 44900 &        # worker 1 (persistent)
rodeo run --place --port 44910 &        # worker 2 (persistent)
rodeo run build.luau --port 44900       # targets worker 1
rodeo run test.luau  --port 44910       # targets worker 2 (in parallel)
```

Each `--place` launch gets a unique session GUID and a unique plugin file, so plugins gate themselves to their own Studio's place — there is no cross-talk.

## VM targeting

A single Studio can host multiple VMs at once: the **edit** VM, plus **server**/**client** VMs when you enter run/test/play modes. `--target` picks which one runs your script. Targets also drive auto-transitions: if you ask for `test:client` from an edit-mode Studio, rodeo enters play mode automatically.

### Target syntax

`--target <mode>:<dom>[:<identity>]`

- `<mode>` — `edit`, `run`, `test`, or `play`. The Studio mode the VM is running in.
- `<dom>` — `edit`, `server`, or `client`. Which DataModel the VM owns. (Available combinations are constrained — see the table below.)
- `<identity>` (optional) — `plugin`, `server`, `client`, or `elevated`. Override the script's identity.

If `--target` is omitted, the default is `edit:plugin`.

### Valid targets

```
edit:plugin                 (default)
edit:elevated

run:server
run:server:plugin
run:server:elevated

test:server
test:server:plugin
test:server:elevated
test:client
test:client:plugin
test:client:elevated

play:server
play:server:plugin
play:server:elevated
play:client                 (append: spawn a new client VM)
play:client:N               (target client #N)
play:client:N:identity      (e.g. play:client:1:plugin)
play:client:plugin          (append + plugin identity)
play:client:elevated
```

`edit:elevated` runs at command-bar identity (above plugin) — useful for APIs gated to elevated identity (`DebuggerManager`, etc.).

### Examples

```bash
# Default: edit-mode plugin VM.
rodeo run script.luau

# Server VM in run mode (Script identity, can access ServerStorage).
rodeo run --target run:server script.luau

# Play test (single-client).
rodeo run --target test:server script.luau
rodeo run --target test:client script.luau

# Multi-client play test — spawn additional clients.
rodeo run --target play:client script.luau         # append a new client
rodeo run --target play:client:1 script.luau       # target client #1
rodeo run --target play:client:1:plugin script.luau

# Elevated identity (above plugin).
rodeo run --target edit:elevated --source 'return tostring(DebuggerManager())'
```

### Auto mode transitions

If the current VM doesn't match the requested target's mode, rodeo transitions the Studio automatically:

- edit → `run:*` enters run mode.
- run/edit → `test:*` enters single-client test mode.
- run/test → `play:*` enters multi-client play mode.

You don't need to manually enter a mode before submitting a script — just specify `--target` and rodeo handles it.

## Script arguments

Pass arguments to scripts using the `--` separator:

```bash
rodeo run script.luau -- arg1 arg2 "arg with spaces"
rodeo run --source 'return function(args) return args end' -- hello world
```

Modules that return a function receive the arguments:

```lua
return function(args)
    print(args[1])  -- "arg1"
    print(args[2])  -- "arg2"
    return args
end
```

Scripts that don't return a function ignore the arguments — no breaking change.

## In-Studio runtime

Scripts have access to a typed standard library — `@rodeo/fs`, `@rodeo/io`, `@rodeo/stream`, `@rodeo/process`, `@rodeo/roblox` — for filesystem, subprocess, IO, and Roblox helpers. Run [`rodeo setup`](#rodeo-setup) once per project to install the alias, then see [runtime.md](runtime.md) for the full reference.

## Directives

Embed default flags into your script files using the `@rodeo` directive comment:

```lua
-- @rodeo run --show-return --target run:server
return function(args)
    return { result = "executed on server" }
end
```

You can also specify default arguments after `--`:

```lua
-- @rodeo run --show-return -- default-arg1 default-arg2
return function(args)
    return args  -- uses directive args if no CLI args provided
end
```

CLI flags override directive defaults:

```bash
rodeo run script.luau                              # uses directive defaults
rodeo run script.luau --target edit:plugin         # override target from directive
rodeo run script.luau -- custom-arg                # override args from directive
rodeo run script.luau --                           # explicitly empty args
```

## Output redirection

```bash
rodeo run script.luau --output output.txt                     # logs/prints → file
rodeo run script.luau --return result.luau                    # return value → Luau source
rodeo run script.luau --return result.json                    # return value → JSON
rodeo run script.luau --output out.txt --return result.luau   # both
```

- `--output <PATH>` — write execution output (prints/logs) to a file instead of stdout.
- `--return <PATH>` — write return value to a file. `.luau`/`.lua` emits a `return { ... }` source file with constructor calls for Roblox types (e.g. `Vector3.new(1,2,3)`); other extensions emit JSON-encoded tagged structs.
- `--show-return` — also print the return value to stdout (combine with `--return` for both).

## Log filtering

Suppress specific log levels:

```bash
rodeo run script.luau --no-warn       # hide warnings
rodeo run script.luau --no-error      # hide errors (still sets exit code)
rodeo run script.luau --no-info       # hide info
rodeo run script.luau --no-print      # hide print() output
rodeo run script.luau --no-output     # disable all output (most efficient)
```

## Return values

Scripts can `return` a value. By default it's silent.

```bash
rodeo run script.luau --show-return                       # print to stdout
rodeo run script.luau --return result.luau                # write to file (.luau emits Luau source)
rodeo run script.luau --return result.json --show-return  # both
result=$(rodeo run script.luau --no-output --show-return) # capture in shell
```

Example:

```lua
return {
    sum   = 5050,
    pos   = Vector3.new(1, 2, 3),
    color = Color3.new(1, 0, 0),
}
```

Behavior by output:

- **`--show-return`** — JSON-encoded one-line: `{"sum":5050,"pos":{"type":"Vector3","value":[1,2,3]},"color":{"type":"Color3","value":[1,0,0]}}`.
- **`--return result.luau`** — emits Luau source: `return { sum = 5050, pos = vector.create(1, 2, 3), color = Color3.new(1, 0, 0) }`. Round-trips via `require()`.
- **`--return result.json`** — emits the JSON tagged-struct form.

Roblox types covered include `Vector3`, `Vector2`, `CFrame`, `Color3`, `UDim`, `UDim2`, `NumberRange`, `Rect`. Plain Luau values JSON-encode normally; types that can't be encoded fall back to `tostring()`.

## Module caching

By default, rodeo bypasses Roblox's `require` cache by cloning module instances and renaming originals on every run. This guarantees fresh code without the deopt cost of `loadstring`/`setfenv`. Static `require()`s work reliably; some dynamic patterns may have edge cases.

Pass `--cache-requires` to use the standard Roblox module cache instead, for better performance when modules aren't changing run-to-run.

## Dependency bundling

External filesystem `require`s are inlined automatically before submission. No flag is required. Use `--sourcemap sourcemap.json` to resolve Wally package paths.

```bash
rodeo run script.luau                              # bundling on by default
rodeo run --sourcemap sourcemap.json script.luau   # with Wally resolution
```

Resolved require kinds:

- `require("./relative/path")` — filesystem-relative.
- `require("@rodeo/fs")`, `require("@rodeo/io")`, etc. — alias resolved via `.rodeo/.luaurc` (set up by `rodeo setup`).
- `require("@lune/...")` — shimmed where possible.
- `require(game.ReplicatedStorage.SomeModule)` — left intact (resolved at runtime in Studio).

## Process roles

`rodeo serve` is a single binary that can run in three roles:

- **default (combined)** — master + studio backend in one process. What you get from `rodeo serve` with no role flags. The combined process listens on `--port` and uses `--port + 1` internally for the plugin's WebSocket connection.
- **`--master`** — master only. Other backends connect over the network.
- **`--studio`** — studio backend only. Connects to a master via `--master-host` / `--master-port`.

The split roles are for distributed setups where the master and Studio hosts differ.

## FFlags

Override Studio FastFlags for a launch:

```bash
rodeo run --place --fflag.override DFFlagSomeFlag=true
rodeo run --place --fflag.override DFFlagA=true --fflag.override DFFlagB=false
rodeo run --place --fflag.file my-fflags.json
```

The `--fflag.file` JSON should be a flat `{ "FlagName": value }` object. rodeo writes the merged settings to Studio's `ClientAppSettings.json` for the launch and restores the original on exit (with file locking so parallel launches don't clobber each other).

## Cleanup behavior

- **Plain `rodeo run --place script.luau`** — Studio is killed when the script finishes.
- **`--detached`** — Studio is left running after rodeo exits.
- **Persistent `rodeo run --place` (no script)** — Ctrl-C or SIGTERM tears down Studio + serve.
- **`--save`** — the temp place file is preserved (in-place or to the given path) instead of deleted.
