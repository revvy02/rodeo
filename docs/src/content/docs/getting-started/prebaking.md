---
title: Prebaking
---

Prebaking is doing expensive or runtime-only work once, ahead of time, inside
Studio's real Roblox runtime, then committing the results into your source
tree. The shipped game reads the precomputed data or assets instead of
recomputing them every session.

It works because rodeo runs your script in an actual Studio DOM, so you have the
full Roblox runtime available (`ContentProvider`, `Animator`, sound playback, the
asset providers), and because rodeo can write a script's output straight back
into your repo. There are two things worth baking: **data** and **instances**.

## Bake data into a module

Some values can only be obtained from a live runtime: an animation's length, the
moment a sound becomes audible, a computed lookup table. Compute them in Studio
and write them into your source tree with
[`roblox.bake`](/rodeo/runtime/roblox/), which serializes a value as a Luau
module.

```luau
-- @rodeo run --place

local roblox = require("@rodeo/roblox")
local ContentProvider = game:GetService("ContentProvider")
local animations = require(game.ReplicatedStorage.shared.assets.animations)

local part = Instance.new("Part")
part.Parent = workspace
local humanoid = Instance.new("Humanoid")
humanoid.Parent = part
local animator = Instance.new("Animator")
animator.Parent = humanoid

local lengths = {}
for name, id in animations do
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    ContentProvider:PreloadAsync({ anim })
    lengths[name] = animator:LoadAnimation(anim).Length
end

roblox.bake("src/shared/data/animationLengths.luau", lengths)
```

Run it:

```bash
rodeo run cacheAnimationLengths.luau
```

`src/shared/data/animationLengths.luau` is now a ready-to-require module:

```luau
return {
    ["idle"] = 4,
    ["walk"] = 0.8333,
}
```

The game requires that module instead of loading every animation at startup just
to read its length.

Roblox types round-trip through their constructors, so baked data keeps its
types when required back:

```luau
roblox.bake("src/shared/data/spawnPoints.luau", {
    lobby = workspace.Lobby.Spawn.CFrame,
    material = Enum.Material.Plastic,
    tint = Color3.new(1, 0, 0),
})
```

```luau
return {
    ["lobby"] = CFrame.new(12, 4, -30, 1, 0, 0, 0, 1, 0, 0, 0, 1),
    ["material"] = Enum.Material.Plastic,
    ["tint"] = Color3.new(1, 0, 0),
}
```

Values with no source representation — Instances, functions — become their
`tostring`. Parent directories are created as needed, and `bake` can be called
as often as you like: several files, or one per iteration of a loop.

For the single-value case there is a flag shorthand: `--return <path>.luau`
writes the script's return value through the same implementation, once, when the
run ends. (A `--return` path that doesn't end in `.luau` is written as JSON
instead.)

## Bake instances into model files

When the output is Roblox instances (generated geometry, fetched
`KeyframeSequence`s, prefabs you want under version control), use
[`@rodeo/roblox`](/rodeo/runtime/roblox/) to export them to `.rbxm` files that
rojo can mount back into the DataModel.

```luau
-- @rodeo run --dom edit --context plugin

local roblox = require("@rodeo/roblox")

local prefabs = game.ReplicatedStorage.prefabs
for _, category in prefabs:GetChildren() do
    for _, prefab in category:GetChildren() do
        roblox.export(`src/ReplicatedStorage/prefabs/{category.Name}/{prefab.Name}.rbxm`, { prefab })
    end
end
```

This turns one-off Studio work into source-controlled `.rbxm` files. It's useful
for splitting a bundled model into per-prefab files, snapshotting
`KeyframeSequenceProvider:GetKeyframeSequenceAsync()` results, or committing a
procedurally generated map.

## Bake images

`EditableImage` objects have no file representation: exporting an instance
whose texture is an in-memory `EditableImage` writes an empty reference. Write
the pixels out with
[`roblox.exportEditableImage`](/rodeo/runtime/roblox/) instead, and load them
back with `roblox.importEditableImage`.

```luau
-- @rodeo run --place

local roblox = require("@rodeo/roblox")
local AssetService = game:GetService("AssetService")

local image = AssetService:CreateEditableImage({ Size = Vector2.new(256, 256) })
-- ... draw into it with WritePixelsBuffer / DrawRectangle / DrawImage ...
roblox.exportEditableImage("src/assets/generated/noise.png", image)
```

The PNG is an ordinary file in the source tree, ready for the upload tooling
the project already uses. `importEditableImage("src/assets/generated/noise.png")`
returns an `EditableImage` for previewing or processing inside Studio without
an upload.

## Bake meshes

`EditableMesh` has no file representation either. Write generated geometry out
as glTF with [`roblox.exportEditableMesh`](/rodeo/runtime/roblox/) and load it
back with `roblox.importEditableMesh`.

```luau
-- @rodeo run --place

local roblox = require("@rodeo/roblox")
local AssetService = game:GetService("AssetService")

local mesh = AssetService:CreateEditableMesh()
-- ... build it with BatchAdd / AddTriangle / SetFaceNormals ...
roblox.exportEditableMesh("src/assets/generated/terrain-chunk.glb", mesh)
```

`.glb` is binary glTF; `.gltf` writes JSON with the buffer embedded. Geometry,
per-corner normals, UVs, colors, and skinning are written. The file opens in
Blender and in Roblox's mesh importer, and `importEditableMesh` returns an
`EditableMesh` for `AssetService:CreateMeshPartAsync(Content.fromObject(mesh), options)`.

## Running bake scripts

Bake scripts are ordinary rodeo scripts, so they lean on the usual conveniences:

- A [directive](/rodeo/getting-started/directives/) at the top encodes the run
  target and `--return` path, so the script is self-describing and you invoke it
  with a bare `rodeo run`.
- Drop them in `.rodeo/` and run them by short name (`rodeo run cacheAnimationLengths`).
