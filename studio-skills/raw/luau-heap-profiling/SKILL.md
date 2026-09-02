---
name: luau-heap-profiling
description: Profile Luau heap memory usage and debug memory leaks using HeapProfilerService. Use this skill when the user wants to analyze memory allocations, take heap snapshots, compare memory usage over time, or find objects leaking memory in their Roblox experience.
---

# Luau Heap Profiling

Use `HeapProfilerService` to programmatically capture and analyze Luau heap memory snapshots. This is the scriptable equivalent of the Developer Console's LuauHeap tool — it lets you take snapshots, compare memory over time, and identify objects leaking memory.

**Security:** Plugin-level security. Usable by plugins, command scripts, and AI agents via MCP. Not available in regular game scripts.

```luau
local HeapProfilerService = game:GetService("HeapProfilerService")
```

## When to Use

- Investigating high memory usage in a Roblox experience
- Finding memory leaks (objects retained in memory that should have been released)
- Comparing memory state before/after an action to see what allocates
- Profiling which scripts, tables, or object types consume the most memory
- Verifying that cleanup code (`:Destroy()`, disconnecting events, clearing tables) actually frees memory

## API Reference

### Methods

**`HeapProfilerService:ClientRequestDataAsync(player: Player): string`**

- Yields until data is ready
- Requests a heap snapshot from the specified player's client
- Returns the heap snapshot data as a JSON string

**`HeapProfilerService:ServerRequestDataAsync(): string`**

- Yields until data is ready
- Requests a heap snapshot from the server
- Returns the heap snapshot data as a JSON string

### Events

**`HeapProfilerService.OnNewData(player: Player, jsonString: buffer, id: number, compressedLength: number, uncompressedLength: number)`**

- Fires when heap profiling data becomes available
- `player`: The player whose client provided the data (or nil for server)
- `jsonString`: Compressed profiling data (buffer)
- `id`: Data identifier for this snapshot
- `compressedLength`: Size of the compressed data in bytes
- `uncompressedLength`: Original uncompressed size in bytes

## Heap Snapshot Data

A heap snapshot represents all Luau-allocated memory at a point in time. It includes:

- **Tables** — All Luau tables, their sizes, and what references them
- **Functions** — Closures and their captured upvalues
- **Threads** — Coroutines and their stack allocations
- **Userdata** — Engine instances (Parts, Frames, etc.) referenced by Luau
- **Strings** — Interned string allocations

Each object in the snapshot has:

- **Size** — Total memory including children (retained size)
- **Self** — Direct memory allocated by this object alone (shallow size)
- **Memory Category** — Engine-assigned label (customizable via `debug.setmemorycategory`)
- **References** — What other objects point to this one (retention path)

## Workflow

### 1. Take a baseline snapshot

Start play mode, let the experience initialize, then capture a snapshot:

```luau
local HeapProfilerService = game:GetService("HeapProfilerService")
local HttpService = game:GetService("HttpService")

local serverData = HeapProfilerService:ServerRequestDataAsync()
return serverData
```

### 2. Perform the action under investigation

Let the user perform whatever action might be leaking (entering/leaving an area, opening/closing a UI, spawning/despawning entities).

### 3. Take a second snapshot and compare

```luau
local HeapProfilerService = game:GetService("HeapProfilerService")

local afterData = HeapProfilerService:ServerRequestDataAsync()
return afterData
```

Compare the two snapshots to identify objects that were allocated but not freed.

### 4. For client-side profiling

```luau
local HeapProfilerService = game:GetService("HeapProfilerService")
local Players = game:GetService("Players")

local player = Players:GetPlayers()[1]
if player then
    local clientData = HeapProfilerService:ClientRequestDataAsync(player)
    return clientData
end
```

## Debugging Memory Leaks

### Common leak patterns

**Setting Parent to nil instead of Destroy:**

```luau
-- LEAKS: instance still referenced, GC cannot collect
part.Touched:Connect(function(hit) ... end)
part.Parent = nil

-- CORRECT: breaks all references and connections and allows collection
part:Destroy()
```

**Tables that accumulate without cleanup:**

```luau
-- LEAKS: cache grows unbounded
local cache = {}
RunService.Heartbeat:Connect(function()
    cache[#cache + 1] = someData
end)
```

### Analysis approach

1. **Identify growth** — Compare snapshot sizes; large increases after an action that should be reversible indicate a leak
2. **Find retained objects** — Look for instances or tables with unexpectedly high counts or sizes
3. **Trace retention paths** — Follow references to understand why objects cannot be garbage collected
4. **Check Unique References** — Instances disconnected from the DataModel but still held by scripts are prime leak suspects
5. **Verify with memory categories** — Use `debug.setmemorycategory("MySystem")` in suspect code to isolate allocations

## Integration with Other Tools

- **Developer Console LuauHeap** — The UI equivalent; provides Graph, Object Tags, Memory Categories, Object Classes, and Unique References views. Use HeapProfilerService for automated/scripted profiling.
- **SceneAnalysisService:GetUnparentedInstancesAsync()** — Finds instances with no Parent still held in memory. Useful alongside heap snapshots for a complete picture.
- **LibMP Counters** — MicroProfiler counters like `**/Luau/heap` track aggregate Luau heap size over time. Use LibMP for real-time monitoring, HeapProfilerService for detailed object-level snapshots.
- **`debug.setmemorycategory(name)`** — Tag allocations in your code so they appear under named categories in the heap snapshot. Essential for isolating specific systems.

## Special Notes for AI Agents

- Always run profiling in Play mode — heap data reflects runtime state, not edit-mode state.
- `ClientRequestDataAsync` requires a valid `Player` object — the client must be connected.
- `ServerRequestDataAsync` must be called from a context with access to the server DataModel.
- The returned data can be large. When presenting results to the user, summarize the top allocators rather than dumping raw JSON.
- For leak detection, always take at least two snapshots: before and after the suspected leaking action. A single snapshot shows current state but cannot distinguish normal allocations from leaks.
- Pair with `SceneAnalysisService:GetUnparentedInstancesAsync()` for a more complete leak analysis — it catches instances that have lost their parent but are still referenced.
