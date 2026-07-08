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
moment a sound becomes audible, a computed lookup table. Compute them in Studio,
`return` the result, and point `--return` at a `.luau` file. rodeo serializes the
return value into a Luau module in your source.

```luau
-- @rodeo run --return src/shared/data/animationLengths.luau --place

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

return lengths
```

Run it:

```bash
rodeo run cacheAnimationLengths.luau
```

rodeo writes the returned table to `src/shared/data/animationLengths.luau` as a
ready-to-require module:

```luau
return {
    idle = 4.0,
    walk = 0.8333,
    -- ...
}
```

Now the game requires that module instead of loading every animation at startup
just to read its length. (A `--return` path that doesn't end in `.luau` is
written as JSON instead.)

## Bake instances into model files

When the output is Roblox instances (generated geometry, fetched
`KeyframeSequence`s, prefabs you want under version control), use
[`@rodeo/roblox`](/rodeo/runtime/roblox/) to export them to `.rbxm` files that
rojo can mount back into the DataModel.

```luau
-- @rodeo run --target edit:plugin

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

## Running bake scripts

Bake scripts are ordinary rodeo scripts, so they lean on the usual conveniences:

- A [directive](/rodeo/getting-started/directives/) at the top encodes the run
  target and `--return` path, so the script is self-describing and you invoke it
  with a bare `rodeo run`.
- Drop them in `.rodeo/` and run them by short name (`rodeo run cacheAnimationLengths`).
