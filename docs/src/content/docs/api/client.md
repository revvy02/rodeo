---
title: client
---

> _This page is auto-generated from `rodeo-client-lune/src/client.luau`._

```luau
local client = require("@rodeo-client-lune/client")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [BackendInfo](#backendinfo) |  |
| [ConnectOpts](#connectopts) |  |
| [ProcessInfo](#processinfo) |  |
| [RodeoClient](#rodeoclient) |  |

---

## Types

### BackendInfo

```luau
type BackendInfo = { id: string, kind: string, name: string }
```

---

### ConnectOpts

```luau
type ConnectOpts = {
	host: string?,
	port: number,
	rodeoBin: string?,
}
```

---

### ProcessInfo

```luau
type ProcessInfo = { [string]: any }
```

---

### RodeoClient

```luau
type RodeoClient = {
	isHealthy: () -> boolean,
	getState: () -> StateSnapshot,
	listProcesses: () -> { ProcessInfo },
	kill: (processId: number) -> (),
	listBackends: (kind: string?) -> { BackendInfo },
	getLocalStudio: () -> studioMod.StudioBackend,
	getStudio: (idOrName: string) -> studioMod.StudioBackend,
	getVms: () -> { vmMod.Vm },
	getVm: (vmId: string) -> vmMod.Vm,
	close: () -> (),
}
```

---
