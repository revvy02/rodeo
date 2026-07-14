<p align="center">
  <img src="assets/plugin/logo.png" width="200" />
</p>

# rodeo

[![Latest release](https://img.shields.io/github/v/release/revvy02/rodeo?include_prereleases&label=latest)](https://github.com/revvy02/rodeo/releases)
[![Latest stable](https://img.shields.io/github/v/release/revvy02/rodeo?label=stable)](https://github.com/revvy02/rodeo/releases)

`rodeo` is an automation tool for Roblox Studio. It lets you execute code in any Studio environment and control Studio from your terminal, while providing the complete studio luau runtime.

> **Status:** macOS and Windows are fully supported. Linux currently is not. Breaking changes to API may happen.

## Examples

### Open a place, run a script, close it

`--place` opens a place ID or a local file, runs the script against it, and closes it when done.

```bash
$ rodeo run --place 1234567890 --show-return --source "return game.Workspace.Name"
"Workspace"

$ rodeo run --place ./game.rbxl script.luau

# rodeo opens Studio in the background by default; --focus brings it to the front
$ rodeo run --place ./game.rbxl --focus script.luau
```

### Keep the place open

`--detached` leaves the Studio open after the run.

```bash
$ rodeo serve                 # terminal 1

$ rodeo run --place 1234567890 --detached --source "print('studio is up')"
studio is up

$ rodeo run --show-return --source "return game.PlaceId"
1234567890
```

### Pipe stdio between the terminal and Studio

Scripts read the terminal's stdin and write to its stdout.

```lua
-- greet.luau
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")

local name = stream.read(io.stdin)
stream.write(io.stdout, `hello, {name}\n`)
```

```bash
$ echo "frank" | rodeo run greet.luau
hello, frank
```

### Run code in any script context or Studio mode

Three orthogonal flags pick where the script runs — all optional, with sensible
defaults. If Studio isn't in the requested mode, rodeo auto-transitions it when
possible.

- `--mode edit|run|test|play` — the Studio mode
- `--context plugin|server|client|elevated` — the run context (cf. Roblox `Script.RunContext`)
- `--dom edit|server|client` — which DataModel (usually inferred from context/mode; `edit` targets the edit DOM even while a session runs)

| Flags | Runs as |
|-------|---------|
| *(none)* | ModuleScript in edit mode (default) |
| `--context elevated` | elevated identity (command bar) in edit mode |
| `--context server` | server Script in run mode |
| `--mode test --context server` | server Script in a play test |
| `--context client` | LocalScript in a play test |
| `--mode test --dom edit` | ModuleScript in the edit DOM while a play test runs |
| `--mode play --context server` | server Script in a multiplayer test |
| `--mode play --dom client` | LocalScript on a client in a multiplayer test |
| `--mode play --dom client --clients <n>` | multiplayer test sized to `n` clients |

`--context` composes with `--dom-id <id>` to run at a chosen context on one
exact DOM (e.g. `--dom-id <id> --context elevated`). `--dom-id` / `--studio-id`
accept a unique id prefix (from `rodeo state`).

```bash
$ rodeo run --context server --show-return --source "return game:GetService('RunService'):IsRunning()"
true
```

### Access live module state in a play test

`--context client` runs the script as a LocalScript in a play test. With `--cache-requires`, the execution has access to the same module state as your running game code. Mutate it in one run, read it back in the next.

```bash
$ rodeo run --context client --cache-requires --source '
local m = require(game.ReplicatedStorage.Counter)
m.value += 1
print("value is now", m.value)'
value is now 1

$ rodeo run --context client --cache-requires --show-return --source "return require(game.ReplicatedStorage.Counter).value"
1
```

### Export and import models

```bash
$ rodeo run --source '
local roblox = require("@rodeo/roblox")
roblox.export("map.rbxm", { workspace.Map })'

$ rodeo run --source '
local roblox = require("@rodeo/roblox")
local roots = roblox.import("map.rbxm")
print(roots[1].ClassName, roots[1].Name)'
Model Map
```

### Write return values to a file

`--return` writes the script's return value to a file. A `.luau` file gets the value serialized as Luau source, preserving data types like `Vector3` or `CFrame`. The output is valid Luau you can `require` from other code.

```bash
$ rodeo run --return dump.luau --source "return { coins = 120, spawn = workspace.Map.Spawn.Position }"
```

```lua
-- dump.luau
return {
	["coins"] = 120,
	["spawn"] = vector.create(0, 5, 0),
}
```

## Docs

**[revvy02.github.io/rodeo](https://revvy02.github.io/rodeo/)**

- [CLI reference](https://revvy02.github.io/rodeo/cli/)
- [@rodeo standard library](https://revvy02.github.io/rodeo/runtime/)

## Companion tools

- **[rbx-microprofiler](https://github.com/revvy02/rbx-microprofiler)** — view + diff Roblox microprofiler dumps captured via `rodeo run --profile`.
