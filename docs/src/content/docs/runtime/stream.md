---
title: stream
---

> _This page is auto-generated from `rodeo-pkg/src/stream.luau`._

```luau
local stream = require("@rodeo-pkg/stream")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [close](#streamclose) | Closes `handle`. Subsequent reads/writes error. |
| [read](#streamread) | Reads from `handle`. Returns the next chunk as a string, or `nil` on EOF. |
| [write](#streamwrite) | Writes `data` to `handle`. `data` is converted to a string via `tostring`. |

---

## Functions and Properties

### stream.close

Closes `handle`. Subsequent reads/writes error.

```luau
(handle: shared.StreamHandle) -> ()
```

---

### stream.read

Reads from `handle`. Returns the next chunk as a string, or `nil` on EOF.

```luau
(handle: shared.StreamHandle) -> string?
```

---

### stream.write

Writes `data` to `handle`. `data` is converted to a string via `tostring`.

```luau
(handle: shared.StreamHandle, data: any) -> ()
```

---
