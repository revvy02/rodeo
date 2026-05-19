---
title: roblox
---

```luau
local roblox = require("@rodeo/roblox")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [export](#robloxexport) | Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`. |
| [import](#robloximport) | Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances. |
| [load](#robloxload) | Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its |

---

## Functions and Properties

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

### roblox.load

Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its

root Instances. Useful for staging fixtures into the DataModel.

```luau
(path: string) -> { Instance }
```

---
