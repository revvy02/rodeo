---
title: roblox
---

```luau
local roblox = require("@rodeo/roblox")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [load](#robloxload) | Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its |

---

## Functions and Properties

### roblox.load

Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its

root Instances. Useful for staging fixtures into the DataModel.

```luau
(path: string) -> { Instance }
```

---
