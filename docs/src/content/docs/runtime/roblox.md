---
title: roblox
---

> _This page is auto-generated from `rodeo-pkg/src/roblox.luau`._

```luau
local roblox = require("@rodeo-pkg/roblox")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [load](#robloxload) | Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its |
| [mcp.call](#robloxmcpcall) | Invokes an MCP tool by name with optional arguments, returning the |

---

## Functions and Properties

### roblox.load

Loads a Roblox model file (`.rbxm`/`.rbxmx`) at `path` and returns its

root Instances. Useful for staging fixtures into the DataModel.

```luau
(path: string) -> { Instance }
```

---

### roblox.mcp.call

Invokes an MCP tool by name with optional arguments, returning the

string response. Routes through the StudioMCP bridge.

```luau
(tool: string, arguments: { [string]: any }?) -> string
```

---
