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
| [Stream](#stream) |  |

---

## Types

### Stream

```luau
type Stream = {
	read: (handle: shared.StreamHandle) -> string?,
	write: (handle: shared.StreamHandle, data: any) -> (),
	close: (handle: shared.StreamHandle) -> (),
}
```

---
