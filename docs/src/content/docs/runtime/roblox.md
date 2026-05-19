---
title: roblox
---

```luau
local roblox = require("@rodeo/roblox")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [export](#robloxexport) | Serializes `instances` and writes the model bytes to `path`. Extension |
| [import](#robloximport) | Reads the model file at `path` and deserializes it via |
| [load](#robloxload) | Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its |

---

## Functions and Properties

### roblox.export

Serializes `instances` and writes the model bytes to `path`. Extension

selects the format: `.rbxm`/`.rbxl` write binary,

`.rbxmx`/`.rbxlx` write XML. Symmetric with `import`.

```luau
(path: string, instances: { Instance }) -> ()
```

---

### roblox.import

Reads the model file at `path` and deserializes it via

`SerializationService:DeserializeInstancesAsync`. Returns the root

Instances. Symmetric with `export`.

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
