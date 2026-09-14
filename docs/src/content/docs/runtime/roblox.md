---
title: roblox
---

```luau
local roblox = require("@rodeo/roblox")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

## Summary

| Entry | Description |
| :--- | :--- |
| [CaptureInfo](#captureinfo) | Size of the written image in pixels. Always the capture's |
| [CaptureOptions](#captureoptions) | Camera and device options for `capture`. All fields optional. |
| [bake](#robloxbake) | Writes `value` to `path` as a Luau module (`return <value>`), so the data |
| [capture](#robloxcapture) | Captures a Studio screenshot and writes it to a stable path, returning |
| [export](#robloxexport) | Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`. |
| [exportEditableImage](#robloxexporteditableimage) | Writes an `EditableImage`'s pixels to `path` as a PNG. Only `.png` is |
| [import](#robloximport) | Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances. |
| [importEditableImage](#robloximporteditableimage) | Loads the PNG or JPEG at `path` into a new `EditableImage` (RGBA8) and |

---

## Types

### CaptureInfo

Size of the written image in pixels. Always the capture's

`Camera.ViewportSize`: the engine's frame is larger on high-DPI displays and

is resampled down to it, so a capture is the same size on every machine and

offset-based UI maps 1:1 onto pixels.

```luau
type CaptureInfo = {
	width: number,
	height: number,
}
```

---

### CaptureOptions

Camera and device options for `capture`. All fields optional.

`cframe` — scripted camera position for the shot (restored after).

`fov` — field of view. `focus` — camera focus CFrame (defaults to 100 studs

along `cframe`'s look vector when `cframe` is set). `settle` — seconds to

wait before capturing.

`device` — a Studio device-simulator preset id to capture as (for example

`"iphone_13"` or `"hd_1080"`); layout, insets and orientation come from the

preset. `viewportSize` — the `Camera.ViewportSize` to capture at, as a

custom desktop device (width at most 7680); with `device`, overrides the

preset's resolution. Either drives Studio's device simulator for the shot

and restores it afterward, the way the camera fields are restored.

```luau
type CaptureOptions = {
	cframe: CFrame?,
	fov: number?,
	focus: CFrame?,
	settle: number?,
	device: string?,
	viewportSize: Vector2?,
}
```

---

## Functions and Properties

### roblox.bake

Writes `value` to `path` as a Luau module (`return <value>`), so the data

can be required straight back into Studio. Roblox types round-trip through

their constructors (vectors, CFrames, colors, enums, …); values with no

source representation (Instances, functions) become their `tostring`.

Parent directories are created as needed. This is the same path

`--return <file>.luau` uses.

```luau
(path: string, value: any) -> ()
```

---

### roblox.capture

Captures a Studio screenshot and writes it to a stable path, returning

that absolute path and the image size. `output` ending in `.png` is the

exact file path; any other value is a directory the auto-named `.png` lands

in; omitted defaults to the `.rodeo/.temp/captures` directory. Relative

paths resolve against the run client's cwd. The image is always exactly

the capture's `Camera.ViewportSize` (the window's, or `viewportSize` /

the `device` preset's). Camera and device-simulator state are restored

after the capture, on error too. Requires a viewport (plugin context, or

client context in a running session). Frames beyond roughly 16384 physical

pixels never complete and fail after 10s, as does a minimized Studio on

Windows (background launches are minimized there; launch focused or

restore the window).

```luau
(output: string?, options: CaptureOptions?) -> (string, CaptureInfo)
```

---

### roblox.export

Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`.

```luau
(path: string, instances: { Instance }) -> ()
```

---

### roblox.exportEditableImage

Writes an `EditableImage`'s pixels to `path` as a PNG. Only `.png` is

supported. Parent directories are created as needed. EditableImage has no

file representation of its own (`export` writes an Object-backed image

content as an empty reference), so this is how generated textures reach

the source tree.

```luau
(path: string, image: EditableImage) -> ()
```

---

### roblox.import

Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances.

```luau
(path: string) -> { Instance }
```

---

### roblox.importEditableImage

Loads the PNG or JPEG at `path` into a new `EditableImage` (RGBA8) and

returns it. Relative paths resolve against the run client's cwd. Studio

bounds EditableImage dimensions; an image it refuses errors with its size.

```luau
(path: string) -> EditableImage
```

---
