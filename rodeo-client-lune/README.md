# rodeo-client-lune

Lune client for [rodeo](https://github.com/revvy02/rodeo). Connects to a `rodeo serve` master and drives Roblox Studio — open Studios, run Luau, capture output, manage multiplayer test sessions.

## Install

```
pesde add rvy/rodeo
```

Requires the `rodeo` CLI on `PATH` (the client spawns / connects to it).

## Usage

```luau
local rodeo = require("@pkg/rodeo")
local task = require("@lune/task")

local client = rodeo.connect({ port = 44899 })
for _ = 1, 20 do
    if client.isHealthy() then break end
    task.wait(0.5)
end

local studio = client.getLocalStudio().open({ background = true })
local r = studio.editVm.runCode({ source = "return 1 + 1", showReturn = true })
print(r.output)  -- contains "2"

studio.close()
client.close()
```

## API

`rodeo.connect(opts)` returns a `RodeoClient` with:
- `isHealthy()`, `getState()`, `listBackends()`, `listProcesses()`
- `getLocalStudio()` → `StudioBackend` for opening Studios
- `close()`

`StudioBackend.open(opts)` / `.openPlace(opts)` / `.openFile(opts)` → `Studio` with:
- `editVm.runCode({ source, target?, showReturn?, ... })` → `RunResult { ok, output, exitCode }`
- `startMultiplayerTest(opts)` → `MultiplayerTestServer`
- `close()`

See [`src/init.luau`](src/init.luau) for the full type surface.
