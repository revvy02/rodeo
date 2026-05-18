---
title: stream
---

```luau
local stream = require("@rodeo/stream")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [StreamHandle](#streamhandle) | Opaque stream identifier. Pass these to `stream.read`/`stream.write`/ |
| [close](#streamclose) | Closes `handle`. Subsequent reads/writes error. |
| [read](#streamread) | Reads from `handle`. Returns the next chunk as a string, or `nil` on EOF. |
| [write](#streamwrite) | Writes `data` to `handle`. `data` is converted to a string via `tostring`. |

---

## Types

### StreamHandle

Opaque stream identifier. Pass these to `stream.read`/`stream.write`/

`stream.close`; you don't access `__handle` directly.

```luau
type StreamHandle = {
	__handle: string,
}
```

---

## Functions and Properties

### stream.close

Closes `handle`. Subsequent reads/writes error.

```luau
(handle: StreamHandle) -> ()
```

---

### stream.read

Reads from `handle`. Returns the next chunk as a string, or `nil` on EOF.

```luau
(handle: StreamHandle) -> string?
```

---

### stream.write

Writes `data` to `handle`. `data` is converted to a string via `tostring`.

```luau
(handle: StreamHandle, data: any) -> ()
```

---
