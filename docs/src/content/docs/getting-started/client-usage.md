---
title: Client usage
---

Drive rodeo from Luau via the `rvy/rodeo` Lune client. This is the same surface the rodeo CLI uses internally — anything you can do from `rodeo run` is one method call away.

## Install

```bash
pesde add rvy/rodeo --target lune
pesde install
```

Then in your script:

```luau
local rodeo = require("@pkg/rodeo")
```

## Connect

Start the server first (see [CLI usage](/rodeo/getting-started/cli-usage/)):

```bash
rodeo serve --port 44872
```

Then:

```luau
local rodeo = require("@pkg/rodeo")

-- Blocks until the server is reachable (default 30s timeout).
local client = rodeo.connect({ port = 44872 })

-- Snapshot of registered backends and VMs.
local state = client.getState()
print(state.vms)

-- Shut down the client (closes the daemon subprocess).
client.close()
```

Override the wait with `readyTimeoutMs` if you need a different deadline:

```luau
local client = rodeo.connect({ port = 44872, readyTimeoutMs = 5000 })
```

## Launching Studio

`backend.open()` boots a blank Studio (no place file) and returns once the edit VM is connected.

```luau
local backend = client.getLocalStudio()
local studio = backend.open({ background = true })

local result = studio.editVm.runCode({
    source = "return 1 + 1",
    showReturn = true,
})

print(result.output)  --> "2"
print(result.ok)      --> true

studio.close()
```

### `open` options

```luau
backend.open({
    background = true,    -- launch off-screen (default: foreground)
    noHud = false,        -- hide Studio's HUD panels
    fflags = {},          -- FFlag overrides for this Studio
    profile = false,      -- attach microprofiler
    logs = "./logs",      -- capture Studio logs to this directory
})
```

### Targeting a specific Studio

If multiple Studios are connected (e.g. across machines), pick one by id or name:

```luau
local backend = client.getStudio("studio-a")
```

`getLocalStudio` resolves the Studio on the same machine as `rodeo serve`.

### Waiting for a specific VM

`backend.open()` blocks until the edit VM is connected. For other VM modes (e.g. after `studio.setMode("run")`), use `waitForVm`:

```luau
local runVm = studio.waitForVm(function(vm)
    return vm.mode == "run:server" and vm.connected
end, 60000)
```

## Opening a place

By place ID:

```luau
local studio = backend.openPlace({
    placeId = 72824109308551,
    background = true,
})

local result = studio.editVm.runCode({
    source = "return game.PlaceId",
    showReturn = true,
})
print(result.output)  --> "72824109308551"

studio.close()
```

By file path:

```luau
local studio = backend.openFile("./my-place.rbxl", { background = true })
studio.editVm.runCode({ source = 'print("editing my-place.rbxl")' })
studio.close()
```

### Saving

After script-driven edits, save the place back out:

```luau
local result = studio.save()
if result.saved then
    print("saved to", result.path)
end
```

## Multiplayer test

`startMultiplayerTest` launches an isolated play-test server process and lets you connect simulated clients. Each is its own VM that you target via the returned handles.

```luau
local backend = client.getLocalStudio()

-- Launch the server VM. No edit Studio required.
local server = backend.startMultiplayerTest({})

-- Run code on the server.
local sr = server.runCode({
    source = "return game:GetService('RunService'):IsRunning()",
    showReturn = true,
})
print(sr.output)  --> "true"

-- Spawn a client and run code on it.
local client1 = server.connectClient()
local cr = client1.runCode({
    source = "return game:GetService('Players').LocalPlayer ~= nil",
    showReturn = true,
})
print(cr.output)  --> "true"

-- Server sees the connected player.
local sr2 = server.runCode({
    source = "return #game:GetService('Players'):GetPlayers()",
    showReturn = true,
})
print(sr2.output)  --> "1"

-- Add more clients as needed; each is its own VM.
local client2 = server.connectClient()

-- Tear down (clients disconnect implicitly when the server closes).
server.close()
```

### Picking a place

By default `startMultiplayerTest` uses a blank place. Override with `placeId` or `placeFile`:

```luau
local server = backend.startMultiplayerTest({
    placeId = 12345,
    -- or:
    -- placeFile = "./my-place.rbxl",
})
```

### Disconnecting a client

To drop a specific client mid-test (e.g. simulate a leave):

```luau
client1.disconnect()
```

Other clients stay connected until `server.close()`.

## Run options

`vm.runCode` accepts an options table that controls source, targeting, return capture, log routing, and more.

### Source

Pass either inline source or a file path — exactly one:

```luau
vm.runCode({ source = 'print("inline")' })

vm.runCode({
    file = "./script.luau",
    sourcemap = "./sourcemap.json",  -- optional, for instance resolution
})
```

### Return values

Return data from your Luau script back to the host:

```luau
local result = vm.runCode({
    source = "return { name = 'Frank', score = 99 }",
    showReturn = true,
})
print(result.output)
--> '{ name = "Frank", score = 99 }'
```

For machine-parseable output, write to a file. `.luau` / `.lua` extensions emit Luau source; any other extension emits JSON:

```luau
vm.runCode({
    source = "return { pos = Vector3.new(1, 2, 3) }",
    returnFile = "./out.json",  -- or "./out.luau"
})
```

### Logs

Stream Studio logs to disk:

```luau
vm.runCode({
    source = 'print("hello")',
    logs = "./.rodeo/logs",
})
```

Per-run `.log` files land in that directory.

Filter which categories the runtime captures:

```luau
vm.runCode({
    source = 'warn("careful")',
    logFilter = {
        enableWarn = true,
        enableError = true,
        enableInfo = false,
        enableOutput = true,
        enableLogs = true,
    },
})
```

### Targeting

Override the VM mode / dom / identity:

```luau
vm.runCode({
    source = "return game:GetService('Workspace')",
    target = "edit:plugin",   -- default — DataModel access, plugin identity
})
```

Common targets:

| `target` string  | What it runs as |
|------------------|------------------|
| `edit:plugin`    | Edit-mode Studio, plugin identity |
| `edit:elevated`  | Edit-mode Studio, command-bar identity (debugger APIs, `@rodeo` runtime) |
| `run:server`     | Standalone server (no clients) |
| `test:server`    | Play-test server |
| `test:client`    | Play-test client with `LocalPlayer` |
| `play:client`    | Multi-client play, client identity |

When you hold a multiplayer handle, routing is implicit — you don't need to set `target`.

### Script arguments

Anything in `scriptArgs` is available to the script via [`process.args`](/rodeo/runtime/process/) from the `@rodeo` runtime:

```luau
vm.runCode({
    source = [[
        local process = require("@rodeo/process")
        print(process.args[1])
    ]],
    scriptArgs = { "hello" },
})
```

### A combined example

```luau
local result = vm.runCode({
    source = 'print("logging"); return { ok = true }',
    target = "run:server",
    showReturn = true,
    returnFile = "./out.json",
    logs = "./logs",
    scriptArgs = { "--mode", "ci" },
    cacheRequires = true,
})

if not result.ok then
    error(`run failed: {result.output}`)
end
```
