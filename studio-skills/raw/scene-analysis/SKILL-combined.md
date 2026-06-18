---
name: scene-analysis
description: Analyze and optimize Roblox scenes using SceneAnalysisService — rendering, memory, instance composition, unparented instances, and animation/audio assets. Use when investigating performance, memory, or leaks in a place.
---

# Scene Analysis

Uses `SceneAnalysisService` to analyze and optimize Roblox game scenes. All commands follow the same cycle:

1. Start play mode (required — `SceneAnalysisService` only works at runtime)
2. Run queries via `SceneAnalysisService`
3. Stop play mode
4. Analyze results and present findings or make edits

## When to Use

- User asks to optimize a scene, check performance, trace memory, or find leaks
- Keywords: `performance`, `memory`, `draw calls`, `triangles`, `scene health`, `unparented`, `leak`, `optimize`, `SceneAnalysisService`

## Commands

| Command | What it does |
|---------|-------------|
| `/scene-health` | Full overview — runs all 6 queries, summarizes rendering, memory, instances, and unparented objects |
| `/optimize-rendering` | Deep rendering analysis — auto-finds geometry hotspots, sweeps camera at player height, measures triangles and draw calls per view, places hotspot markers in the scene |
| `/optimize-memory` | Memory analysis — script VM memory, animation clip memory, audio asset memory with reference counts |
| `/fix-leaks` | Traces unparented instances to host scripts, reads the source, identifies cleanup patterns, offers to apply fixes |

## SceneAnalysisService queries

| Query | Returns |
|-------|---------|
| `GetInstanceCompositionAsync()` | Instance counts by category and class |
| `GetTriangleCompositionAsync()` | Triangle and draw call counts by render pass (view-dependent) |
| `GetScriptMemoryAsync()` | Per-script Luau VM heap memory |
| `GetUnparentedInstancesAsync()` | Instances held in memory but not in the DataModel, traced to host scripts |
| `GetAnimationMemoryAsync()` | Loaded animation clip memory with owner Animators |
| `GetAudioMemoryAsync()` | Loaded audio asset memory with owner Sound/AudioPlayer instances |

See `QuerySpecs.md` in this skill for full data shape documentation.

## Key facts

- **Play mode is required.** `SceneAnalysisService` queries runtime data (GPU render passes, Luau VM heap, loaded assets). It doesn't work in edit mode.
- **Triangle composition is view-dependent.** A single measurement only represents one viewpoint — `/optimize-rendering` handles this with an automatic hotspot sweep.
- **Set `CameraType = Scriptable`** before programmatically moving the camera, or the PlayerModule will override it each frame.
- **Shadows should be excluded** from triangle/draw call budgets — engine-driven, not creator-controllable.
- **Animation and audio assets are reference-counted.** Memory can only be freed by removing ALL references.
- **Server mode** — running memory and unparented instance queries from a server session can surface server-side issues (server-side animation leaks are especially common).

## Tone

Frame findings as opportunities, not problems. Be helpful and collaborative. Avoid language like "CRITICAL", "WARNING", "bloat", "problem", "offender", "over budget", "failing". Don't assign grades or severity labels. Present data clearly and let the creator decide what to act on.

## Reference points (rendering)

~800k triangles and ~600 draw calls is roughly the range where most devices can maintain 60fps. Present these as context, not pass/fail criteria — some creators target higher fidelity and accept lower framerates. Ask about framerate/device target before making strong recommendations.

Internally, each draw call costs roughly the equivalent of 20,000 triangles in GPU overhead — use this to prioritize draw call reduction in recommendations, but don't show the ratio to the creator.

---


## SceneAnalysisService Query Output Specifications

Each query has its own method on `SceneAnalysisService`:

```lua
SceneAnalysisService:GetInstanceCompositionAsync()       --> InstanceCompositionResult
SceneAnalysisService:GetScriptMemoryAsync()              --> ScriptMemoryResult
SceneAnalysisService:GetUnparentedInstancesAsync()       --> UnparentedInstancesResult
SceneAnalysisService:GetTriangleCompositionAsync()       --> TriangleCompositionResult
SceneAnalysisService:GetAnimationMemoryAsync()           --> AnimationMemoryResult
SceneAnalysisService:GetAudioMemoryAsync()               --> AudioMemoryResult
```

Every node in every query result is a `ValueTable` with at least a `Name` field. Interior nodes have `Children` (a `ValueArray` of child `ValueTable`s). Leaf nodes have no `Children`. Numeric metrics are always `int`.

---

### InstanceComposition

Counts every Instance under scanned services, categorized by type and grouped by class name.

**Scanned services:** Workspace, Players, Lighting, MaterialService, ReplicatedFirst, ReplicatedStorage, ServerScriptService, ServerStorage, StarterGui, StarterPack, StarterPlayer, Teams, SoundService, TextChatService.

#### Tree Structure

```
Root
├── Name: "InstanceComposition"          string
├── Size: <total instance count>         int
└── Children[]
    └── Category
        ├── Name: <category>             string   e.g. "3D Objects", "Scripts", "UI"
        ├── Size: <instances in category> int
        └── Children[]
            └── ClassEntry (leaf)
                ├── Name: <className>    string   e.g. "Part", "Script", "Frame"
                └── Size: <count>        int
```

#### Categories

| Category | Representative types |
|---|---|
| 3D Objects | BasePart, Model, Camera |
| Physics | Attachment, Constraint, JointInstance, WeldConstraint, ... |
| UI | GuiBase, BasePlayerGui, UIBase, ProximityPrompt, ClickDetector, TextChannel, ... |
| Lights | Light |
| PostProcessing | PostEffect, Highlight, Atmosphere, Sky, Clouds |
| Scripts | LuaSourceContainer, BindableEvent, RemoteEvent, ... |
| Audio | Sound, SoundEffect, AudioPlayer, Wire, ... |
| Animation | Animator, AnimationController, Animation, KeyframeSequence, IKControl |
| Values | ValueBase |
| Character | CharacterAppearance, Humanoid, HumanoidDescription, BaseWrap, ... |
| Textures | FaceInstance, SurfaceAppearance, MaterialVariant |
| Meshes | DataModelMesh |
| Particles | ParticleEmitter, Fire, Trail, Beam, ... |
| Services & Storage | Player, Folder, Configuration |
| Misc | Tool, Backpack, Team, ForceField, ... |
| Unclassified | Anything not matching the above |

#### Example Output

```lua
{
  Name = "InstanceComposition",
  Size = 12450,
  Children = {
    { Name = "3D Objects", Size = 5200, Children = {
        { Name = "Part", Size = 3100 },
        { Name = "MeshPart", Size = 1800 },
        { Name = "Model", Size = 300 },
    }},
    { Name = "UI", Size = 2100, Children = {
        { Name = "Frame", Size = 900 },
        { Name = "TextLabel", Size = 700 },
        { Name = "UIListLayout", Size = 500 },
    }},
    -- ...
  }
}
```

---

### ScriptMemory

Reports per-script Luau VM heap memory, obtained via `ScriptContext::requestRootObjectsMemory`. This query is **async** (the heap walk is deferred to a later frame).

**Requires flags:** `SceneAnalysisServiceEnabled`, `STUDIOPLAT37936`.

#### Tree Structure

```
Root
├── Name: "ScriptMemory"                 string
├── Size: <totalVmMemory>               int      total Luau VM memory (bytes)
└── Children[]
    └── ServiceCategory
        ├── Name: <service>              string   e.g. "ServerScriptService", "PlayerScripts"
        ├── Size: <sum of subcategories> int      bytes
        └── Children[]
            ├── ModuleScriptGroup
            │   ├── Name: "ModuleScripts"         string
            │   ├── Size: <sum of modules>       int      bytes
            │   └── Children[]
            │       └── ModuleEntry (leaf)
            │           ├── Name: <dotted path>  string   e.g. "ServerScriptService.Shared.Utils"
            │           └── Size: <bytes>        int
            └── ScriptsGroup
                ├── Name: "Scripts"              string
                ├── Size: <sum of scripts>       int      bytes
                └── Children[]
                    └── ScriptEntry (leaf)
                        ├── Name: <dotted path>  string   e.g. "ServerScriptService.MainScript"
                        └── Size: <bytes>        int
```

#### Notes

- Modules are entries whose Instance resolves to a `ModuleScript` via `isA()`.
- Scripts are entries whose Instance resolves to a `Script` or `LocalScript` (`isA("Script")`).
- Entries that don't resolve to a known script Instance in the DataModel are silently dropped.
- The service category is derived from the first segment of the dotted path (before the first `.`).

#### Example Output

```lua
{
  Name = "ScriptMemory",
  Size = 8388608,       -- 8 MB total VM memory
  Children = {
    { Name = "ServerScriptService", Size = 524288, Children = {
        { Name = "ModuleScripts", Size = 409600, Children = {
            { Name = "ServerScriptService.Shared.Utils", Size = 204800 },
            { Name = "ServerScriptService.Shared.Config", Size = 204800 },
        }},
        { Name = "Scripts", Size = 114688, Children = {
            { Name = "ServerScriptService.MainScript", Size = 114688 },
        }},
    }},
    { Name = "ReplicatedStorage", Size = 262144, Children = {
        { Name = "ModuleScripts", Size = 262144, Children = {
            { Name = "ReplicatedStorage.SharedModule", Size = 262144 },
        }},
    }},
  }
}
```

---

### UnparentedInstances

Finds Instances held by Luau references that are **not** descendants of the DataModel (i.e. unparented / leaked). Traces GC reference paths to identify the host script responsible.

#### Tree Structure

```
Root
├── Name: "UnparentedInstances"          string
├── Size: <total unparented count>       int
└── Children[]
    └── HostScript
        ├── Name: <script path>          string   e.g. "ServerScriptService.Gameplay.Combat"
        │                                         or "(unknown)" if untraceable
        ├── Size: <count from this host>  int
        └── Children[]
            └── ClassEntry (leaf)
                ├── Name: <className>    string   e.g. "Part", "Frame", "Sound"
                └── Size: <count>        int
```

#### Notes

- Uses `InstanceBridge::getInstancesHeldByState` to find all Instances referenced by the Luau VM.
- Filters out any Instance that is a descendant of the DataModel (those are normal).
- Performs a full GC heap enumeration (`luaC_enumheap`) and traces backward edges to identify the host script.
- Host script is extracted from the first `LUA_TFUNCTION` chunk name containing an `=` prefix (the `=ScriptPath` convention).

#### Example Output

```lua
{
  Name = "UnparentedInstances",
  Size = 47,
  Children = {
    { Name = "ServerScriptService.Gameplay.Combat", Size = 30, Children = {
        { Name = "Part", Size = 22 },
        { Name = "Attachment", Size = 8 },
    }},
    { Name = "(unknown)", Size = 17, Children = {
        { Name = "Frame", Size = 12 },
        { Name = "Sound", Size = 5 },
    }},
  }
}
```

---

### TriangleComposition

Reports GPU triangle and draw call counts by render pass type, sourced from `StatsService::getPerfData()`.

#### Tree Structure

```
Root
├── Name: "TriangleComposition"          string
├── Sizes                                ValueTable
│   ├── Triangles: <total triangles>     int
│   └── Drawcalls: <total draw calls>    int
└── Children[]
    └── RenderPassEntry (leaf)
        ├── Name: <pass type>            string
        └── Sizes                        ValueTable
            ├── Triangles: <count>       int
            └── Drawcalls: <count>       int
```

#### Render Pass Types

| Name | Description |
|---|---|
| Opaque | Opaque geometry |
| Transparent | Transparent geometry |
| Terrain | Voxel/smooth terrain |
| Grass | Terrain grass decoration |
| UI | Screen-space UI |
| Decal | Decal rendering |
| Cloud | Volumetric clouds |
| GenericPostProcess | Generic post-processing |
| SSAO | Screen-space ambient occlusion |
| DOF | Depth of field |
| Particles | Particle systems |
| Sky | Skybox |
| Shadows | Shadow map rendering |
| Undefined | Uncategorized |

Entries with zero triangles **and** zero draw calls are omitted.

#### Example Output

```lua
{
  Name = "TriangleComposition",
  Sizes = { Triangles = 245000, Drawcalls = 1200 },
  Children = {
    { Name = "Opaque",      Sizes = { Triangles = 180000, Drawcalls = 800 } },
    { Name = "Transparent", Sizes = { Triangles = 25000,  Drawcalls = 150 } },
    { Name = "Shadows",     Sizes = { Triangles = 30000,  Drawcalls = 200 } },
    { Name = "UI",          Sizes = { Triangles = 10000,  Drawcalls = 50  } },
  }
}
```

---

### AnimationMemory

Reports loaded `AnimationClip` memory, deduplicated by clip pointer. Every clip entry has `Name = AssetId` and an `Owners` array listing all owning Animators. Out-of-DataModel clips are grouped separately.

#### Tree Structure

```
Root
├── Name: "AnimationMemory"              string
├── Size: <total clip bytes>             int
└── Children[]
    ├── ClipEntry
    │   ├── Name: <asset ID>             string
    │   ├── Size: <clip bytes>           int
    │   ├── AssetId: <asset ID>          string
    │   └── Owners[]                     ValueArray
    │       └── OwnerEntry
    │           ├── Name: <owner path>   string
    │           └── ClassName: <class>   string
    │
    └── OutOfDmGroup
        ├── Name: "Not In DataModel"     string
        ├── Size: <sum of clip bytes>    int
        └── Children[]
            └── ClipEntry
                ├── Name: <asset ID>     string
                ├── Size: <clip bytes>   int
                ├── AssetId: <asset ID>  string
                └── Owners[]             ValueArray
                    └── OwnerEntry
                        ├── Name: <owner path>   string
                        └── ClassName: <class>   string
```

#### Notes

- Clips are deduplicated by `AnimationClip*` pointer (the animation cache guarantees one clip per asset).
- Walks both the DataModel tree and Luau-held Animator instances (to catch unparented animators).

#### Example Output

```lua
{
  Name = "AnimationMemory",
  Size = 1048576,
  Children = {
    { Name = "rbxassetid://111", Size = 32768, AssetId = "rbxassetid://111",
      Owners = {
        { Name = "Workspace.Player.Humanoid.Animator", ClassName = "Animator" },
    }},
    { Name = "rbxassetid://444", Size = 65536, AssetId = "rbxassetid://444",
      Owners = {
        { Name = "Workspace.NPC1.Humanoid.Animator", ClassName = "Animator" },
        { Name = "Workspace.NPC2.Humanoid.Animator", ClassName = "Animator" },
    }},
    { Name = "Not In DataModel", Size = 32768, Children = {
        { Name = "rbxassetid://555", Size = 32768, AssetId = "rbxassetid://555",
          Owners = {
            { Name = "Animator", ClassName = "Animator" },
        }},
    }},
  }
}
```

---

### AudioMemory

Reports loaded audio asset memory, deduplicated by asset ID. Groups by owning Instance's parent path, with special handling for shared assets.

#### Tree Structure

**Single-parent assets (all owners share the same parent):**

```
Root
├── Name: "AudioMemory"                  string
├── Size: <total audio bytes>            int
└── Children[]
    ├── ParentGroup (when parent has multiple audio children)
    │   ├── Name: <parent path>          string   e.g. "Workspace.Map.Ambience"
    │   ├── Size: <sum of asset bytes>   int
    │   └── Children[]
    │       └── AssetEntry (leaf)
    │           ├── Name: <full instance path>  string   e.g. "Workspace.Map.Ambience.WindSound"
    │           ├── Size: <bytes>          int
    │           └── AssetId: <asset ID>    string
    │
    ├── FlatAssetEntry (when parent has exactly one audio child)
    │   ├── Name: <full instance path>   string   e.g. "Workspace.Map.Ambience.WindSound"
    │   ├── Size: <bytes>                int
    │   └── AssetId: <asset ID>          string
```

**Shared assets (owners under different parents):**

```
    └── SharedAssetEntry
        ├── Name: <asset ID>             string
        ├── Size: <bytes>                int
        ├── AssetId: <asset ID>          string
        └── Owners[]                     ValueArray
            └── OwnerEntry
                ├── Name: <full path>    string
                └── ClassName: <class>   string   "Sound" or "AudioPlayer"
```

#### Notes

- Asset sizes come from `SoundService::getSoundMemoryData()`, which reports in MB (converted to bytes).
- Walks all audio instances from `SoundService::getAudioInstances()` (covers both `Sound` and `AudioPlayer`).
- Assets with no loaded memory data will show `Size = 0`.

#### Example Output

```lua
{
  Name = "AudioMemory",
  Size = 5242880,
  Children = {
    { Name = "Workspace.Map.BGMusic", Size = 2097152,
      AssetId = "rbxassetid://111" },
    { Name = "Workspace.Map.SFX", Size = 1048576, Children = {
        { Name = "Workspace.Map.SFX.Explosion", Size = 524288, AssetId = "rbxassetid://222" },
        { Name = "Workspace.Map.SFX.Gunshot",   Size = 524288, AssetId = "rbxassetid://333" },
    }},
    { Name = "rbxassetid://444", Size = 2097152, AssetId = "rbxassetid://444",
      Owners = {
        { Name = "Workspace.Zone1.Ambient", ClassName = "Sound" },
        { Name = "Workspace.Zone2.Ambient", ClassName = "Sound" },
    }},
  }
}
```

---


## Command Workflows

The sections below describe example workflows the user may invoke as slash commands (e.g. `/scene-health`, `/vi-click`). Each section is a reference for one specific use case of this skill — read the matching section when the user invokes that command, otherwise treat them as background context. They are not mandatory steps for every interaction with this skill.

### `/scene-health` — Scene Health Overview

_Run a full scene overview using all SceneAnalysisService queries and surface opportunities for improvement._

Run a comprehensive scene analysis and highlight areas where there may be room to improve performance.

#### Tone guidance

Be conversational and supportive. Frame findings as opportunities, not problems. Use language like:
- "Here's what I found..." / "A few things stood out..."
- "You might be able to save some draws by..." / "One option would be..."
- "This is worth a look" / "Something to keep in mind"

Avoid: "CRITICAL", "WARNING", "bloat", "problem", "offender", "over budget", "failing". Don't assign grades or severity labels. Just present the data clearly and let the creator decide what to act on.

#### Workflow

##### 1. Start play mode
Use `start_stop_play(is_start: true)` to enter play mode. Wait briefly for the game to initialize.

##### 2. Run all queries
Execute the following Luau script via `execute_luau` to gather all scene data at once:

```lua
local sas = game:GetService("SceneAnalysisService")
local HttpService = game:GetService("HttpService")

local results = {}

local queries = {
    { name = "InstanceComposition",  fn = function() return sas:GetInstanceCompositionAsync() end },
    { name = "TriangleComposition",  fn = function() return sas:GetTriangleCompositionAsync() end },
    { name = "ScriptMemory",         fn = function() return sas:GetScriptMemoryAsync() end },
    { name = "UnparentedInstances",  fn = function() return sas:GetUnparentedInstancesAsync() end },
    { name = "AnimationMemory",      fn = function() return sas:GetAnimationMemoryAsync() end },
    { name = "AudioMemory",          fn = function() return sas:GetAudioMemoryAsync() end },
}

for _, q in ipairs(queries) do
    local ok, data = pcall(q.fn)
    if ok then
        results[q.name] = data
    else
        results[q.name] = { error = tostring(data) }
    end
end

return HttpService:JSONEncode(results)
```

##### 3. Stop play mode
Use `start_stop_play(is_start: false)` to return to edit mode.

##### 4. Analyze and report

Parse the JSON results and present a friendly overview covering these areas:

###### Rendering
For a quick health check, the initial TriangleComposition from the default camera is fine. Note the reference points:
- **Reference points:** ~800k triangles and ~600 draw calls is roughly the range where most devices can maintain 60fps. But this is a starting point, not a rule — some creators are targeting higher fidelity and are fine with lower framerates. Present these as context, not as pass/fail criteria. If the numbers are high, mention the reference point and ask what framerate/device target they're aiming for before making strong recommendations.
- **Exclude Shadows entirely** from calculations — subtract shadow tris and draws from totals before comparing
- Focus on creator-controllable passes: Opaque, Transparent, UI, Decal, Particles, Cloud, PostProcess
- Skip Terrain and Grass unless Terrain makes up a large portion — in that case, gently ask if they've considered mesh-based environments as an alternative
- Present the per-pass breakdown as a simple table showing triangles and draws
- If numbers look high, mention that `/optimize-rendering` can do a full hotspot sweep to find the most demanding views in the scene

###### Scene Composition
From InstanceComposition:
- Note total instance count and the biggest categories
- Internally estimate memory and join time from instance count (each instance ≈ 0.5 KB, replication ≈ 10k/sec). Do NOT share these numbers or formulas. Instead, if the count is high enough to matter (e.g. 50k+ instances → ~25 MB, ~5s join), mention it naturally: "With this many instances, players might notice a bit of a wait when joining" or "this is a pretty dense scene — load times could be noticeable on lower-end devices"
- Call out anything interesting about the composition shape
- If Decal/Texture instance counts are high, mention that these can contribute to draw calls and MaterialVariants may be an alternative

###### Memory (Scripts)
From ScriptMemory:
- Note total VM memory
- List the top few scripts by memory — just the highlights
- Most scenes will be dominated by core PlayerModule scripts; that's normal and worth mentioning

###### Memory (Assets)
From AnimationMemory + AudioMemory:
- Note total memory for each
- Call out the largest assets and how many places reference them
- Flag any "Not In DataModel" animation clips — these are worth investigating
- Mention that audio and animation assets are reference-counted, so reducing memory means deciding whether an entire asset is needed

###### Unparented Instances
From UnparentedInstances:
- A small number is completely normal (core scripts often hold a few intentionally)
- Only call attention to this if counts are notably high (>50) or if heavy types like Parts/MeshParts are accumulating
- If it looks normal, a quick "nothing unusual here" is fine

##### 5. Output format

Present the overview as a natural summary with sections. End with a "Next steps" section that suggests which deeper-dive skills might be useful based on what stood out:
- If rendering numbers are high: "You could run `/optimize-rendering` to dig into what's driving the draw calls"
- If there are notable unparented instances: "`/fix-leaks` can help trace those back to specific scripts"
- If memory looks interesting: "`/optimize-memory` can take a closer look at what's using the most memory"

Keep the whole thing concise and scannable.

### `/optimize-rendering` — Optimize Rendering

_Analyze scene triangle counts and draw calls, identify what's driving rendering cost, and suggest ways to improve._

Take a closer look at what's contributing to the scene's rendering cost and find opportunities to improve performance.

#### Tone guidance

Be helpful and collaborative. Creators have put a lot of work into their scenes — the goal is to help them get the most out of their content, not to criticize their choices. Use language like:
- "The biggest chunk of your draws is coming from..." / "Most of your triangles are in..."
- "One thing that could help is..." / "You might get some wins by..."
- "A few options to consider..."

Avoid: "over budget", "bloat", "problem", "offender", "inefficient", "failing". Present data clearly and frame suggestions as options.

Do not present the draw call / triangle cost equivalence to the user. Internally, each draw call costs roughly the equivalent of 20,000 triangles in GPU overhead — use this to prioritize draw call reduction in your recommendations, but don't show the ratio or the math to the creator.

#### Workflow

##### 1. Start play mode
Use `start_stop_play(is_start: true)`. Wait for the game to initialize.

##### 2. Hotspot sweep — find the most demanding views automatically

TriangleComposition is **view-dependent** — results change dramatically based on camera position. Rather than guessing where to look, scan the scene for geometry clusters and measure from each one.

**Important:** Set `CameraType = Scriptable` before moving the camera, otherwise the PlayerModule will override your CFrame each frame.

###### Step 2a: Find geometry hotspots via adaptive subdivision

Use a two-level approach: coarse grid to find dense regions, then subdivide only the top cells to pinpoint hotspots. This keeps the cell count manageable.

```lua
local HttpService = game:GetService("HttpService")

local parts = {}
for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("BasePart") and obj.ClassName ~= "Terrain" then
        table.insert(parts, {
            x = obj.Position.X, y = obj.Position.Y, z = obj.Position.Z,
            isMesh = obj:IsA("MeshPart"),
        })
    end
end

local minX, minZ = math.huge, math.huge
local maxX, maxZ = -math.huge, -math.huge
for _, p in ipairs(parts) do
    minX = math.min(minX, p.x); maxX = math.max(maxX, p.x)
    minZ = math.min(minZ, p.z); maxZ = math.max(maxZ, p.z)
end

local function scoreParts(cellParts)
    local s = 0
    for _, p in ipairs(cellParts) do s += if p.isMesh then 3 else 1 end
    return s
end

local function partsInBox(allParts, x0, z0, x1, z1)
    local result = {}
    for _, p in ipairs(allParts) do
        if p.x >= x0 and p.x < x1 and p.z >= z0 and p.z < z1 then
            table.insert(result, p)
        end
    end
    return result
end

-- Level 1: coarse 256-stud grid
local COARSE = 256
local coarseCells = {}
for cx = math.floor(minX / COARSE), math.floor(maxX / COARSE) do
    for cz = math.floor(minZ / COARSE), math.floor(maxZ / COARSE) do
        local x0, z0 = cx * COARSE, cz * COARSE
        local cellParts = partsInBox(parts, x0, z0, x0 + COARSE, z0 + COARSE)
        if #cellParts > 0 then
            table.insert(coarseCells, { x0 = x0, z0 = z0, parts = cellParts, score = scoreParts(cellParts) })
        end
    end
end
table.sort(coarseCells, function(a, b) return a.score > b.score end)

-- Level 2: subdivide top 4 coarse cells into 64-stud cells
local FINE = 64
local fineCells = {}
for i = 1, math.min(4, #coarseCells) do
    local coarse = coarseCells[i]
    for sx = 0, (COARSE / FINE) - 1 do
        for sz = 0, (COARSE / FINE) - 1 do
            local x0 = coarse.x0 + sx * FINE
            local z0 = coarse.z0 + sz * FINE
            local cellParts = partsInBox(coarse.parts, x0, z0, x0 + FINE, z0 + FINE)
            if #cellParts > 0 then
                local sumX, sumZ, minY = 0, 0, math.huge
                for _, p in ipairs(cellParts) do
                    sumX += p.x; sumZ += p.z; minY = math.min(minY, p.y)
                end
                table.insert(fineCells, {
                    score = scoreParts(cellParts), count = #cellParts,
                    cx = sumX / #cellParts, cz = sumZ / #cellParts, groundY = minY,
                })
            end
        end
    end
end
table.sort(fineCells, function(a, b) return a.score > b.score end)

local hotspots = {}
for i = 1, math.min(6, #fineCells) do
    local c = fineCells[i]
    table.insert(hotspots, {
        rank = i, score = c.score, parts = c.count,
        x = math.floor(c.cx + 0.5), y = math.floor(c.groundY + 0.5), z = math.floor(c.cz + 0.5),
    })
end

return HttpService:JSONEncode({
    totalParts = #parts, coarseCells = #coarseCells, fineCells = #fineCells, hotspots = hotspots,
})
```

###### Step 2b: Sweep camera through hotspots — 4 cardinal directions at player height

At each hotspot, test all 4 cardinal directions at player camera height (~5.5 studs above ground) and record the worst-case view. This finds demanding sightlines — a view corridor can be expensive even when local part density is low.

```lua
local HttpService = game:GetService("HttpService")
local sas = game:GetService("SceneAnalysisService")
local camera = workspace.CurrentCamera

camera.CameraType = Enum.CameraType.Scriptable

local EYE_HEIGHT = 5.5

-- Insert hotspots from step 2a
local hotspots = {
    -- { name = "Hotspot 1", x = ..., y = ..., z = ..., parts = ... },
}

local results = {}

for _, spot in ipairs(hotspots) do
    local groundY = spot.y + EYE_HEIGHT
    local bestTris, bestDraws, bestDir, bestPasses = 0, 0, "", {}

    local directions = {
        { name = "North", dx = 0, dz = 1 },
        { name = "East",  dx = 1, dz = 0 },
        { name = "South", dx = 0, dz = -1 },
        { name = "West",  dx = -1, dz = 0 },
    }

    for _, dir in ipairs(directions) do
        local camPos = Vector3.new(spot.x - dir.dx * 10, groundY + 3, spot.z - dir.dz * 10)
        local target = Vector3.new(spot.x + dir.dx * 50, groundY, spot.z + dir.dz * 50)
        camera.CFrame = CFrame.lookAt(camPos, target)
        task.wait(0.75)

        local ok, tri = pcall(function() return sas:GetTriangleCompositionAsync() end)
        if ok then
            local shadowTris, shadowDraws = 0, 0
            local passes = {}
            for _, child in ipairs(tri.Children) do
                if child.Name == "Shadows" then
                    shadowTris = child.Sizes.Triangles
                    shadowDraws = child.Sizes.Drawcalls
                else
                    table.insert(passes, { name = child.Name, tris = child.Sizes.Triangles, draws = child.Sizes.Drawcalls })
                end
            end
            local adjTris = tri.Sizes.Triangles - shadowTris
            local adjDraws = tri.Sizes.Drawcalls - shadowDraws
            if adjDraws > bestDraws then
                bestTris, bestDraws, bestDir, bestPasses = adjTris, adjDraws, dir.name, passes
            end
        end
    end

    table.insert(results, {
        name = spot.name,
        position = string.format("(%d, %d, %d)", spot.x, spot.y, spot.z),
        partsInCell = spot.parts,
        worstDirection = bestDir,
        adjustedTris = bestTris,
        adjustedDraws = bestDraws,
        passes = bestPasses,
    })
end

-- Also grab InstanceComposition once (view-independent)
local ok2, inst = pcall(function() return sas:GetInstanceCompositionAsync() end)

return HttpService:JSONEncode({ sweep = results, instanceComposition = ok2 and inst or nil })
```

Present the sweep as a table sorted by draw calls. Note that part density doesn't always predict rendering cost — sightlines matter. A hotspot with fewer local parts may see more geometry through a long view corridor.

##### 3. Deep-dive: frustum instance audit (at the most demanding hotspot)

After the sweep, position the camera at the hotspot with the highest draw calls and run a frustum audit to understand what's in view. Execute via `execute_luau`:

```lua
local HttpService = game:GetService("HttpService")
local camera = workspace.CurrentCamera

local cf = camera.CFrame
local fov = math.rad(camera.FieldOfView)
local aspect = camera.ViewportSize.X / camera.ViewportSize.Y
local nearDist = camera.NearPlaneZ
local farDist = -500

local pos = cf.Position
local look = cf.LookVector
local right = cf.RightVector
local up = cf.UpVector

local halfVFov = fov / 2
local halfHFov = math.atan(math.tan(halfVFov) * aspect)

local function inFrustum(worldPos)
    local toObj = worldPos - pos
    local z = toObj:Dot(look)
    if z < -nearDist or z > -farDist then return false end
    local x = toObj:Dot(right)
    if math.abs(x) > z * math.tan(halfHFov) + 5 then return false end
    local y = toObj:Dot(up)
    if math.abs(y) > z * math.tan(halfVFov) + 5 then return false end
    return true
end

local materialCounts = {}
local classCounts = {}
local transparentCount = 0
local transparentPlasticCount = 0
local totalVisible = 0

-- Track unique Material+MaterialVariant+MeshId combos (drives instancing breaks)
local instanceCombos = {}

for _, obj in ipairs(workspace:GetDescendants()) do
    if obj:IsA("BasePart") and inFrustum(obj.Position) then
        totalVisible += 1

        local mat = tostring(obj.Material)
        materialCounts[mat] = (materialCounts[mat] or 0) + 1

        local cls = obj.ClassName
        classCounts[cls] = (classCounts[cls] or 0) + 1

        -- Track instancing combos for MeshParts
        if obj:IsA("MeshPart") then
            local meshId = obj.MeshId
            local matVariant = obj.MaterialVariant
            local comboKey = mat .. "|" .. matVariant .. "|" .. meshId
            instanceCombos[comboKey] = (instanceCombos[comboKey] or 0) + 1
        end

        if obj.Transparency > 0 and obj.Transparency < 1 then
            local isGlass = (obj.Material == Enum.Material.Glass)
            local hasSurfaceAppearance = obj:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil
            if not isGlass and not hasSurfaceAppearance then
                transparentCount += 1
                if obj.Material == Enum.Material.Plastic or obj.Material == Enum.Material.SmoothPlastic then
                    transparentPlasticCount += 1
                end
            end
        end
    end
end

local decalCount = 0
for _, obj in ipairs(workspace:GetDescendants()) do
    if (obj:IsA("Decal") or obj:IsA("Texture")) and obj.Parent and obj.Parent:IsA("BasePart") then
        if inFrustum(obj.Parent.Position) then
            decalCount += 1
        end
    end
end

-- Summarize instancing: count unique combos and how many are singletons
local uniqueCombos = 0
local singletonCombos = 0
for _, count in pairs(instanceCombos) do
    uniqueCombos += 1
    if count == 1 then singletonCombos += 1 end
end

return HttpService:JSONEncode({
    totalVisibleParts = totalVisible,
    transparentParts = transparentCount,
    transparentPlasticParts = transparentPlasticCount,
    decals = decalCount,
    byMaterial = materialCounts,
    byClass = classCounts,
    instancing = {
        uniqueMeshCombos = uniqueCombos,
        singletonCombos = singletonCombos,
        totalMeshParts = classCounts["MeshPart"] or 0,
    },
})
```

##### 4. Stop play mode
Use `start_stop_play(is_start: false)`.

##### 5. Place hotspot markers in the scene

After stopping play, place markers so the creator can find the hotspots in the editor. Execute via `execute_luau` (in edit mode):

```lua
-- Insert the hotspot results from step 2b here
local hotspotData = {
    -- { name = "Hotspot 1", x = ..., y = ..., z = ..., draws = ..., tris = ..., direction = "East" },
}

-- Clean up any previous hotspot folder
local existing = workspace:FindFirstChild("Hotspots")
if existing then existing:Destroy() end

local folder = Instance.new("Folder")
folder.Name = "Hotspots"
folder.Parent = workspace

for i, spot in ipairs(hotspotData) do
    local marker = Instance.new("Part")
    marker.Name = string.format("Hotspot_%d_%s_%dk_%dd", i, spot.direction, math.floor(spot.tris / 1000), spot.draws)
    marker.Size = Vector3.new(4, 8, 4)
    marker.Position = Vector3.new(spot.x, spot.y + 4, spot.z)
    marker.Anchored = true
    marker.CanCollide = false
    marker.CanQuery = false
    marker.CanTouch = false
    marker.Transparency = 1
    marker.Parent = folder
end

return "Placed " .. #hotspotData .. " hotspot markers in Workspace.Hotspots"
```

The markers are invisible, non-collidable, and anchored. Their names encode the hotspot rank, worst direction, triangle count, and draw count (e.g. `Hotspot_1_East_1392k_1614d`) so the creator can find them in the Explorer and understand what each one represents. Mention to the creator that they can select a marker to jump to that location.

##### 6. Analyze triangle composition

###### Reference points
- **Reference point:** ~800,000 triangles and ~600 draw calls is roughly where most devices can maintain 60fps. This is context, not a hard limit — some creators are targeting higher fidelity and accept lower framerates on some devices. Present the numbers and ask what their target is before framing anything as "too high."
- **Exclude Shadows** from calculations entirely — subtract shadow tris and draws from totals
- Present the adjusted numbers alongside the reference conversationally (e.g. "Your scene is rendering about 1.4M triangles and 1,200 draws from this view. For 60fps on most devices, the sweet spot is around 800k and 600 — but it depends on what you're going for.")
- Internally, prioritize draw call reduction over triangle reduction — each draw call is roughly equivalent to 20k triangles in GPU cost, so draw calls are usually the bigger lever. Don't share this ratio with the creator.

###### Creator-controllable passes
Focus on passes the creator can directly influence:
- **Opaque** — main geometry (Parts, MeshParts, Models)
- **Transparent** — transparent/translucent objects
- **UI** — ScreenGuis, BillboardGuis
- **Decal** — Decals and Textures on surfaces
- **Particles** — ParticleEmitters, Fire, Trail, Beam
- **Cloud** — Volumetric clouds
- **GenericPostProcess / SSAO / DOF** — post-processing effects

###### Excluded passes (do NOT count toward targets)
- **Shadows** — entirely engine-driven. Exclude and don't mention as something to fix.
- **Terrain** — if it's a large portion of the remaining count, gently ask if they've considered mesh-based environments as an alternative
- **Grass** — terrain grass decoration

###### Report format
Show a clean table without percentage columns:
```
Pass         | Triangles   | Draws
-------------|-------------|------
Opaque       | 1,271,000   | 884
Transparent  | 7,100       | 169
Terrain      | 130,000     | 191
...
Adjusted Total | 1,427,000 | 1,268
```

##### 7. Correlate with instance composition + frustum audit

Cross-reference the data to identify where the biggest opportunities are:

###### Draw call opportunities
- **Instancing breaks (Material + MaterialVariant + MeshId combos):** Roblox can instance identical MeshParts efficiently, but each unique combination of Material, MaterialVariant, and MeshId is a separate draw batch. If `uniqueMeshCombos` is high relative to `totalMeshParts`, there's an opportunity to standardize. If `singletonCombos` is high, many meshes aren't benefiting from instancing at all. Suggest consolidating MaterialVariants or reusing the same MeshId where meshes are similar.
- **Part.Transparency:** Flag parts using `Part.Transparency` (non-zero, non-one) that are NOT Glass and do NOT have a SurfaceAppearance. If `transparentPlasticParts` is notable, suggest switching to **Glass material** — it looks great for windows, barriers, and similar elements, and it batches properly. SurfaceAppearance alpha is another batch-friendly option.
- **Decals / Texture instances:** Each adds a draw call. If there are many in view, suggest **MaterialVariants** as an alternative — they participate in instancing and don't add extra draw calls the way Decals and Textures do. They work well when the Decal/Texture is approximating a surface treatment (weathering, color variation, etc.) rather than a specific image.
- **Material variety:** If the frustum audit shows many distinct base materials, mention that consolidating materials helps with batching — the renderer can batch parts more effectively when they share the same material setup.
- **Many small parts:** If there are a lot of visible parts, mention that merging nearby parts or using fewer, more detailed meshes can help.

###### Triangle opportunities
- If Opaque is the main contributor and there are many MeshParts, suggest reviewing mesh complexity or LOD usage
- If Opaque is high with many simple Parts, suggest mesh consolidation
- Note particle and UI contributions if they're meaningful

###### Instance count considerations
Internally estimate the impact of total instance count (each instance ≈ 0.5 KB, replication ≈ 10k/sec). Do NOT share these numbers or formulas with the creator. If the count is high enough to affect experience (e.g. 50k+), mention it naturally in terms of what the player would feel: "a scene this dense might take a moment to load when players join" or "on lower-end devices, the instance count could affect load times." If the count is reasonable, no need to mention it at all.

##### 8. Suggestions

Present suggestions as a menu of options, not a to-do list:
- "If you'd like to reduce draw calls, the biggest opportunities are probably in [X] and [Y]"
- "For triangles, the main area to look at would be [Z]"
- Offer to explore specific areas of the game tree to find concrete instances to work with
- If the user wants to proceed, use `search_game_tree` and `inspect_instance` to find specific instances and offer modifications

**Common suggestions to offer:**
- Transparent Plastic/SmoothPlastic parts -> switch to **Glass** material if the look works (windows, barriers, panels)
- Decals/Textures for surface variation -> replace with **MaterialVariants** where they can approximate the look
- Many unique Material+MaterialVariant+MeshId combos -> consolidate MaterialVariants or standardize MeshIds to improve instancing
- SurfaceAppearance alpha for transparency that needs to stay on a specific material

### `/optimize-memory` — Optimize Memory

_Analyze script, animation, and audio memory usage and surface opportunities to reduce memory footprint._

Take a closer look at memory usage across scripts, animations, and audio to find opportunities to reduce the scene's memory footprint.

#### Tone guidance

Be helpful and informative. Memory usage is often just a natural result of the content in the scene — don't frame large numbers as mistakes. Use language like:
- "The biggest memory consumers are..." / "Here's where most of the memory is going..."
- "If you're looking to reduce memory, one option would be..."
- "This is shared across N instances, so it's being used efficiently"

Avoid: "bloat", "problem", "excessive", "waste". Present the data and let the creator decide what's worth changing.

#### Workflow

##### 1. Start play mode
Use `start_stop_play(is_start: true)`. Wait for the game to initialize.

##### 2. Run client-side queries
Execute via `execute_luau`:

```lua
local sas = game:GetService("SceneAnalysisService")
local HttpService = game:GetService("HttpService")

local results = {}

local queries = {
    { name = "ScriptMemory",    fn = function() return sas:GetScriptMemoryAsync() end },
    { name = "AnimationMemory", fn = function() return sas:GetAnimationMemoryAsync() end },
    { name = "AudioMemory",     fn = function() return sas:GetAudioMemoryAsync() end },
}

for _, q in ipairs(queries) do
    local ok, data = pcall(q.fn)
    if ok then
        results[q.name] = data
    else
        results[q.name] = { error = tostring(data) }
    end
end

return HttpService:JSONEncode(results)
```

##### 3. Stop client, run server-side queries
Server-side animation and script memory is worth checking — server-side leaks are common and invisible from the client.

Stop the client session with `start_stop_play(is_start: false)`, then start a server session via `execute_luau`:

```lua
task.spawn(function()
    game:GetService("StudioTestService"):ExecuteRunModeAsync("Server")
end)
return "starting server"
```

Wait a moment for the server to initialize, then run the same memory queries again. Label results as "Server" vs "Client" in the report.

##### 4. Stop play mode
Use `start_stop_play(is_start: false)`.

##### 5. Analyze script memory

From ScriptMemory results:
- Report total Luau VM memory in a friendly way
- List the **top 10 scripts by memory** with human-readable sizes (KB/MB)
- Group by service to show the overall shape
- Most scenes will be dominated by core PlayerModule scripts (camera, controls, etc.) — that's completely normal and worth noting: "Most of this is the standard Roblox player scripts, which is typical"
- For any notably large custom scripts, offer to take a look at the source to see if there are easy wins (use `script_read`)
- When reading scripts, look for: large table accumulation, unbounded caching, storing instance references that could be looked up on demand, large string building

##### 6. Analyze animation memory

From AnimationMemory results:
- Report total animation clip memory
- List the largest clips with their asset IDs and how many Animators reference them
- Clips shared by many owners are efficient (deduplication is working well) — call this out positively
- **"Not In DataModel" clips** are worth flagging — these are loaded by Animators that aren't in the game hierarchy, which usually means they're left over from something. Suggest looking into the Animator lifecycle.
- **Key context:** Animation clips are reference-counted. The memory for a clip stays loaded as long as any Animator has it loaded. Reducing clip memory means either removing the clip entirely or ensuring all Animators that loaded it are cleaned up.

##### 7. Analyze audio memory

From AudioMemory results:
- Report total audio memory
- List the largest assets with their IDs and what references them
- Shared assets (with Owners array) are being deduplicated — mention this positively
- For very large individual assets, mention the size in context: "This engine sound is 7.3 MB — if you're looking to save memory, a shorter loop or lower sample rate could help"
- **Key context:** Audio assets are also reference-counted. The memory stays loaded as long as any Sound or AudioPlayer references the asset.

##### 8. Summary and options

Present a concise summary of where memory is going, then offer options:
- "Your scene is using about X MB of audio, Y KB of animation clips, and Z MB of script memory"
- Highlight the top 2-3 largest items across all categories
- Frame suggestions as choices: "If you wanted to free up the most memory, the biggest single item is [X]. Want me to take a closer look?"
- If "Not In DataModel" animation clips are present, suggest `/fix-leaks` as a natural next step
- Offer to read specific scripts if the creator wants to explore optimization opportunities

### `/fix-leaks` — Fix Leaks

_Check for unparented instances, trace them to scripts, and help clean them up if needed._

Check for unparented instances in the scene, trace them back to their source scripts, and offer to help clean things up.

#### Tone guidance

Be matter-of-fact and helpful. Unparented instances are a normal part of development — some are intentional, some are leftovers. Don't treat them as bugs or failures. Use language like:
- "I found N unparented instances — here's where they're coming from..."
- "A few of these look intentional, but there are some that might be worth cleaning up"
- "This pattern sometimes leaves instances around — here's one way to handle it"

Avoid: "leak", "bug", "problem", "broken" when possible. Use "unparented instances" or "instances held in memory" instead of "leaked instances". When a fix is appropriate, frame it as a cleanup opportunity.

#### Workflow

##### 1. Start play mode
Use `start_stop_play(is_start: true)`. Wait for the game to initialize. If the user wants to let the game run for a while first to let things accumulate, that's fine.

##### 2. Run unparented instances query
Execute via `execute_luau`:

```lua
local sas = game:GetService("SceneAnalysisService")
local HttpService = game:GetService("HttpService")

local ok, data = pcall(function()
    return sas:GetUnparentedInstancesAsync()
end)

if ok then
    return HttpService:JSONEncode(data)
else
    return HttpService:JSONEncode({ error = tostring(data) })
end
```

##### 3. Stop client, run from server mode
Server-side unparented Animators and Parts are especially common. Stop the client session with `start_stop_play(is_start: false)`, then start a server session via `execute_luau`:

```lua
task.spawn(function()
    game:GetService("StudioTestService"):ExecuteRunModeAsync("Server")
end)
return "starting server"
```

Wait a moment for the server to initialize, then run the same unparented instances query. Compare client vs server results.

##### 4. Stop play mode
Use `start_stop_play(is_start: false)`.

##### 5. Analyze results

If `Size` is 0: "No unparented instances found — everything looks clean."

**Context:** A small number of unparented instances is completely normal. Core scripts like PlayerModule intentionally hold some BindableEvents, Animations, and Parts as internal implementation details. These aren't something to worry about.

For each host script, consider:
- **Small counts (<5) of lightweight types** (BindableEvent, ValueBase, Animation): Almost certainly intentional. Mention them briefly but don't suggest changes.
- **Larger counts or heavier types** (Parts, MeshParts, Frames): Worth a closer look. These take more memory and may be accumulating over time.
- **`(unknown)` host:** The GC couldn't trace ownership — mention this as something that's harder to track down.

###### Report format
Keep it conversational:
```
Found 47 unparented instances across 3 scripts:

- Gameplay.Combat is holding 30 instances (22 Parts, 8 Attachments) — this is the main one worth looking at
- ClickToMoveDisplay has 4 (1 Animation, 3 Parts) — likely intentional, part of how the module works  
- CameraInput has 3 BindableEvents — normal, these are used internally
```

##### 6. Read and diagnose host scripts

For scripts with notable counts, use `script_read` to look at the source. Common patterns that leave instances around:

**Setting Parent to nil instead of calling Destroy()**
```lua
part.Parent = nil  -- instance still referenced
-- vs
part:Destroy()  -- cleans up properly
```

**Event connections keeping references alive**
```lua
local part = Instance.new("Part")
part.Touched:Connect(function(hit) ... end)
-- closure captures 'part', keeping it alive even after unparenting
```

**Tables that accumulate without cleanup**
```lua
local cache = {}
-- instances added but never removed from cache
```

**Temporary Animators not destroyed**
```lua
local animator = Instance.new("Animator")
-- used briefly, then forgotten — especially common on server
```

**Clones not destroyed after use**
```lua
local clone = template:Clone()
clone.Parent = workspace
-- later: clone.Parent = nil but clone variable still exists
```

##### 7. Suggest fixes

For scripts where cleanup would help:
- Point to the specific pattern in the source
- Suggest a concrete change (usually adding a `:Destroy()` call)
- Ask if they'd like you to apply it via `multi_edit`

When applying fixes:
- Be conservative — just add the cleanup, don't refactor surrounding code
- If the pattern isn't clear-cut, say so: "I'm not 100% sure this is unintentional — want me to add cleanup here, or would you rather leave it?"

##### 8. Re-verify (optional)

If fixes were applied, offer to run the game again and compare:
- "Want me to run the check again to see if that helped?"
- Show a simple before/after count
