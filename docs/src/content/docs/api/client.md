---
title: client
---

```luau
local client = require("@rodeo-client-lune/client")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

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
	-- Max time to wait for the server to come up. Default 30000ms.
	readyTimeoutMs: number?,
	-- Poll interval while waiting for the server. Default 200ms.
	readyPollMs: number?,
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
