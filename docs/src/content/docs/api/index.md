---
title: Luau API
description: Drive rodeo programmatically from Luau (Lune today, Lute soon).
---

A Luau library for driving rodeo programmatically: launch Studio, run Luau in it, capture output and return values, save place files, run multiplayer tests. Same surface from [Lune](https://lune-org.github.io/docs) today and Lute soon.

A `rodeo serve` must already be running on the same port — the API client connects to it, it does not start one.

For shell usage of rodeo, see [cli.md](cli.md). For the in-Studio runtime your scripts get, see [runtime.md](runtime.md).

## Connecting

```luau
local client = rodeo.connect({
    port = 44900,
    -- host    = "localhost",  -- optional
    -- rodeoBin = "bin/rodeo", -- optional
})
-- ... use client ...
client.close()
```

## Concepts

- **`RodeoClient`** — the top-level handle from `connect()`. Discovers backends and VMs, exposes health/state, manages process lifecycle.
- **`StudioBackend`** — a connected Studio host. Has `open*` methods that launch a Studio with a place loaded, and `startMultiplayerTest` for headless server/client tests.
- **`Studio`** — a launched Studio instance. Owns one or more VMs, can switch modes (edit/run/test/play), save the place file, close.
- **`Vm`** — a script-execution surface (edit / server / client). `runCode` submits a script and returns its result.

You walk: `client → backend → studio → studio.editVm → runCode`.

## Launching a Studio and running a script

```luau
local backend = client.getLocalStudio()
local studio = backend.open({ background = true })   -- blocks until the edit VM connects

local result = studio.editVm.runCode({
    source = 'print("hello"); return 42',
    showReturn = true,
})

print(result.ok, result.exitCode, result.output)

studio.close()
```

`backend.open(opts)` opens a fresh empty place. To open a published place by ID or a local file:

```luau
backend.openPlace({ placeId = 72824109308551 })
backend.openFile("game.rbxl")
```

## Running a script file with a sourcemap

```luau
studio.editVm.runCode({
    file       = "scripts/build.luau",
    sourcemap  = "sourcemap.json",   -- for Wally / Rojo require resolution
    showReturn = true,
    scriptArgs = { "--mode", "release" },
})
```

## Multiplayer test

A multiplayer test is a headless Studio test session — no edit Studio required. The server handle is itself a `Vm`, so you can submit code to it directly. `connectClient` spawns a paired client VM into the same session.

```luau
local backend = client.getLocalStudio()
local server = backend.startMultiplayerTest({})

server.runCode({ source = "print('on the server')" })

local clientVm = server.connectClient()
clientVm.runCode({ source = "print('on the client')" })

clientVm.disconnect()
server.close()
```

## Saving the place

```luau
local result = studio.save()
if result.saved then
    print("saved to", result.path)
else
    warn("save failed:", result.error)
end
```

## Listing and waiting for VMs

```luau
for _, vm in studio.getVms() do
    print(vm.vmId, vm.mode, vm.dom, vm.connected)
end

local serverVm = studio.waitForVm(function(v)
    return v.dom == "server" and v.mode == "test"
end, 10000)
```

## Mode transitions

Calling `runCode` with a `target` like `run:server`, `test:client`, or `play:server` automatically transitions the Studio into the right mode. You can also drive transitions explicitly with `studio.setMode("edit" | "run" | "test" | "play")`.

After a transition, `studio.serverVm` and `studio.clientVm` are populated for the relevant modes.

See [VM targeting](cli.md#vm-targeting) for the target grammar.

## Reference

### `connect(opts) -> RodeoClient`

| Field | Type | Default | Notes |
|---|---|---|---|
| `port` | `number` | required | The port `rodeo serve` is listening on. |
| `host` | `string?` | `"localhost"` | Master host. |
| `rodeoBin` | `string?` | `"rodeo"` | Path to the rodeo binary. |

### `RodeoClient`

| Method | Returns |
|---|---|
| `isHealthy()` | `boolean` |
| `getState()` | `{ vms = { VmSnapshot, ... } }` |
| `listProcesses()` | `{ ProcessInfo }` |
| `kill(processId)` | — |
| `listBackends(kind?)` | `{ BackendInfo }` |
| `getLocalStudio()` | `StudioBackend` |
| `getStudio(idOrName)` | `StudioBackend` |
| `getVms()` | `{ Vm }` |
| `getVm(vmId)` | `Vm` |
| `close()` | — |

### `StudioBackend`

Fields: `id: string`, `name: string`.

| Method | Returns |
|---|---|
| `open(opts?)` | `Studio` (fresh empty place) |
| `openPlace(opts)` | `Studio` (published place by ID) |
| `openFile(path, opts?)` | `Studio` (local `.rbxl`/`.rbxlx`) |
| `startMultiplayerTest(opts?)` | `MultiplayerTestServer` |

`OpenOpts` (shared by `open` / `openPlace` / `openFile`):

| Field | Type | Notes |
|---|---|---|
| `fflags` | `{ string }?` | FFlag overrides as `"KEY=VALUE"` strings. |
| `background` | `boolean?` | If true, don't bring Studio to the foreground. |
| `profile` | `boolean?` | Enable microprofiler auto-capture. |
| `logs` | `string?` | Directory for collected Studio logs. |
| `noHud` | `boolean?` | Strip Studio UI panels. Restored on exit. |

`OpenPlaceOpts` adds `placeId: number` (required).

`StartMultiplayerTestOpts`:

| Field | Type | Notes |
|---|---|---|
| `placeFile` | `string?` | Local `.rbxl`/`.rbxlx`. |
| `placeId` | `number?` | Place ID instead of a file. |
| `fflags` | `{ string }?` | FFlag overrides. |
| `profile` | `boolean?` | Microprofiler capture. |
| `runId` | `string?` | Caller-supplied run ID for matching profiler dumps. |
| `noHud` | `boolean?` | Strip Studio UI panels. |

### `Studio`

Fields: `sessionGuid`, `backendId`, `editVm`, `serverVm?`, `clientVm?`.

| Method | Returns |
|---|---|
| `setMode(mode)` | — — `"edit"`, `"run"`, `"test"`, or `"play"`. |
| `getMode()` | `string` |
| `save()` | `SaveResult` (`{ saved: boolean, path: string?, error: string? }`) |
| `close()` | — |
| `getVms()` | `{ Vm }` |
| `waitForVm(pred, timeoutMs?)` | `Vm` (defaults to 60s timeout) |

### `Vm`

Fields: `vmId`, `backendId`, `mode`, `dom`, `sessionGuid?`, `placeId`, `gameName`, `connected`, `activeRuns`.

| Method | Returns |
|---|---|
| `runCode(opts)` | `RunResult` (`{ ok: boolean, output: string, exitCode: number }`) |

`RunCodeOpts`:

| Field | Type | Notes |
|---|---|---|
| `source` | `string?` | Inline Luau source (mutually exclusive with `file`). |
| `file` | `string?` | Path to a `.luau` file. |
| `sourcemap` | `string?` | Rojo sourcemap.json for instance-path resolution and Wally requires. |
| `target` | `string?` | `mode:dom[:identity]` — see [VM targeting](cli.md#vm-targeting). |
| `showReturn` | `boolean?` | Include the return value in `output`. |
| `cacheRequires` | `boolean?` | Use Roblox's standard module cache. |
| `verbose` | `boolean?` | Verbose logging. |
| `scriptArgs` | `{ string }?` | Args passed to the script's `function(args, ...)`. |
| `profile` | `string?` | Enable microprofiler capture; optionally direct dumps to this directory. |
| `logs` | `string?` | Collect Studio logs to this directory. |
| `returnFile` | `string?` | Write the return value to this host-side path. `.luau`/`.lua` emits Luau source; other extensions emit JSON. |
| `processName` | `string?` | Label shown in `rodeo ps`. |
| `logFilter` | `LogFilter?` | Per-level enable flags. |

`LogFilter`: `{ enableWarn?, enableError?, enableInfo?, enableOutput?, enableLogs? }`. Omitted = level enabled. Mirrors the CLI [log filtering](cli.md#log-filtering) flags.

### `MultiplayerTestServer`

A `Vm`, plus:

| Method | Returns |
|---|---|
| `connectClient()` | `MultiplayerTestClient` — spawns a paired client VM. |
| `close()` | — |

### `MultiplayerTestClient`

A `Vm`, plus:

| Method | Returns |
|---|---|
| `disconnect()` | — leave the test; the server stays up. |

## See also

- [cli.md](cli.md) — CLI reference. Targeting, return values, and log filtering work the same way as the Luau API.
- [runtime.md](runtime.md) — `@rodeo/*` runtime library available inside scripts you submit.
