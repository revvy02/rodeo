---
title: daemon
---

> _This page is auto-generated from `rodeo-client-lune/src/daemon.luau`._

```luau
local daemon = require("@rodeo-client-lune/daemon")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [Daemon](#daemon) |  |
| [StreamCallback](#streamcallback) |  |

---

## Types

### Daemon

```luau
type Daemon = {
	call: (method: string, params: any?) -> any,
	registerStream: (streamId: string, cb: StreamCallback) -> (),
	unregisterStream: (streamId: string) -> (),
	shutdown: () -> (),
}
```

---

### StreamCallback

```luau
type StreamCallback = (method: string, params: { [string]: any }) -> ()
```

---
