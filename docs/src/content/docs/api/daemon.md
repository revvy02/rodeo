---
title: daemon
---

```luau
local daemon = require("@rodeo-client-lune/daemon")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

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
