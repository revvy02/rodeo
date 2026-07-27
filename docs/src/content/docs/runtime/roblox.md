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
| [CaptureOptions](#captureoptions) | Camera options for `capture`. All fields optional. |
| [capture](#robloxcapture) | Captures a Studio screenshot and copies it to a stable path, returning |
| [export](#robloxexport) | Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`. |
| [import](#robloximport) | Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances. |

---

## Types

### CaptureOptions

Camera options for `capture`. All fields optional.

`cframe` — scripted camera position for the shot (restored after).

`fov` — field of view. `focus` — camera focus CFrame (defaults to 100 studs

along `cframe`'s look vector when `cframe` is set). `settle` — seconds to

wait before capturing.

```luau
type CaptureOptions = {
	cframe: CFrame?,
	fov: number?,
	focus: CFrame?,
	settle: number?,
}
```

---

## Functions and Properties

### roblox.capture

Captures a Studio screenshot and copies it to a stable path, returning

that absolute path. `output` ending in `.png` is the exact file path; any

other value is a directory the auto-named `.png` lands in; omitted

defaults to the `.rodeo-screenshots` directory. Relative paths resolve

against the run client's cwd. Temporary scripted-camera state is restored

after the capture. Requires a viewport (plugin context, or client context

in a running session). macOS only.

```luau
(output: string?, options: CaptureOptions?) -> string
```

---

### roblox.export

Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`.

```luau
(path: string, instances: { Instance }) -> ()
```

---

### roblox.import

Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances.

```luau
(path: string) -> { Instance }
```

---
