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
| [export](#robloxexport) | Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`. |
| [import](#robloximport) | Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances. |

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
