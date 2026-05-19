---
title: Runtime usage
---

Scripts run via `rodeo run` (or via the client's `runCode`) have a small standard library mounted at `@rodeo/*`:

```luau
local fs = require("@rodeo/fs")
local io = require("@rodeo/io")
local process = require("@rodeo/process")
local stream = require("@rodeo/stream")
local roblox = require("@rodeo/roblox")
```

These modules let your in-Studio code touch the host machine — read/write files, run shell commands, pipe to stdout, load `.rbxm` fixtures, call MCP tools. Full reference is in [@rodeo runtime](/rodeo/runtime/); the examples below show common patterns.

## Reading and writing files

`fs.open` returns a `StreamHandle`; pair it with `stream.read` / `stream.write` / `stream.close`:

```luau
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")

-- Write
local f = fs.open("notes.txt", "w")
stream.write(f, "line one\n")
stream.write(f, "line two\n")
stream.close(f)

-- Read
local f2 = fs.open("notes.txt", "r")
local contents = stream.read(f2)
stream.close(f2)
print(contents)  --> "line one\nline two\n"
```

### JSON config

```luau
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")
local HttpService = game:GetService("HttpService")

local f = fs.open("config.json", "r")
local raw = stream.read(f)
stream.close(f)

local config = HttpService:JSONDecode(raw)
print(config.gameName, config.version)
```

### Listing directories

```luau
local fs = require("@rodeo/fs")

for _, entry in fs.listdir(".") do
    print(entry.name, entry.type)  -- type: "file" | "dir"
end
```

`fs.exists`, `fs.stat`, `fs.mkdir`, `fs.remove`, `fs.rmdir`, `fs.copy`, and `fs.type` round out the surface — see the [fs reference](/rodeo/runtime/fs/).

### Binary files

For non-text data, use `stream.readBytes` / `stream.writeBytes` instead of the string-based versions. They return / accept a Luau `buffer`:

```luau
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")

local r = fs.open("sprite.png", "r")
local data = stream.readBytes(r)  -- buffer
stream.close(r)

print(buffer.len(data), "bytes")

local w = fs.open("copy.png", "w")
stream.writeBytes(w, data)
stream.close(w)
```

The string-based `stream.read`/`stream.write` corrupt non-UTF-8 bytes; always use the `Bytes` variants for binary files.

## Piping to stdout

`io.stdout` (and `io.stderr`) are stream handles. Writing to them feeds the terminal that ran `rodeo run`, so your script becomes pipeable:

```luau
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")

for i = 1, 10 do
    stream.write(io.stdout, `value-{i}\n`)
end
```

```bash
rodeo run gen.luau | sort -u | head -5
```

For interactive prompts, `stream.read(io.stdin)` blocks until the user types a line:

```luau
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")

stream.write(io.stdout, "name? ")
local name = stream.read(io.stdin)
stream.write(io.stdout, `hello, {name}\n`)
```

## Script arguments

Anything after `--` (CLI) or in `scriptArgs` (client) shows up in `process.args`:

```luau
local process = require("@rodeo/process")

if #process.args == 0 then
    error("usage: rodeo run script.luau -- <name>")
end
print("hello,", process.args[1])
```

```bash
rodeo run greet.luau -- frank
```

`process.env`, `process.cwd()`, `process.homedir()`, and `process.execpath()` round out the host-introspection set.

## Running shell commands

`process.run` blocks and captures output:

```luau
local process = require("@rodeo/process")

local result = process.run({ "git", "rev-parse", "--abbrev-ref", "HEAD" }, {
    stdio = "piped",
})
local branch = string.gsub(result.stdout, "%s+$", "")
print("on branch", branch)
```

`process.system` takes a shell command string instead of an argv list:

```luau
local result = process.system("ls -la | head -5", { stdio = "piped" })
print(result.stdout)
```

`process.create` spawns without blocking — use it for long-running children you want to talk to via stream handles. The [process reference](/rodeo/runtime/process/) covers the full options table (`cwd`, `env`, per-stream `stdio` overrides).

## Roblox models

`roblox.import` reads a model file from disk via `SerializationService` and returns its root Instances:

```luau
local roblox = require("@rodeo/roblox")

local roots = roblox.import("fixtures/test-rig.rbxm")
for _, inst in roots do
    inst.Parent = workspace
end
```

`roblox.export` writes Instances back out as a model file. The destination extension selects the format:

- `.rbxm` / `.rbxl` — binary (smaller, faster)
- `.rbxmx` / `.rbxlx` — XML (human-readable, diff-friendly)

```luau
local roblox = require("@rodeo/roblox")

local folder = Instance.new("Folder")
folder.Name = "Snapshot"
-- ...populate folder...

roblox.export("out/snapshot.rbxm", { folder })   -- binary
roblox.export("out/snapshot.rbxmx", { folder })  -- XML
```

Useful for staging test fixtures, snapshotting Studio state, or moving subtrees between sessions.

`roblox.load` exists as a legacy alternative that loads via Studio's content asset system instead of `SerializationService` — prefer `import` for new code.

## Combining: snapshot game state to disk

```luau
local fs = require("@rodeo/fs")
local stream = require("@rodeo/stream")
local process = require("@rodeo/process")
local HttpService = game:GetService("HttpService")

local snapshot = {
    branch = string.gsub(process.run({ "git", "rev-parse", "--short", "HEAD" }, { stdio = "piped" }).stdout, "%s+$", ""),
    placeId = game.PlaceId,
    players = #game:GetService("Players"):GetPlayers(),
    workspaceChildren = #workspace:GetChildren(),
}

local f = fs.open(`.rodeo/snapshots/{snapshot.branch}.json`, "w")
stream.write(f, HttpService:JSONEncode(snapshot))
stream.close(f)
```

## Where to go next

- **[@rodeo runtime](/rodeo/runtime/)** — full API reference for `fs`, `io`, `process`, `stream`, `roblox`
- **[Client usage](/rodeo/getting-started/client-usage/)** — same APIs callable from outside Studio via `rodeo-client-lune`
