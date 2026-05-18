---
title: vm
---

```luau
local vm = require("@rodeo-client-lune/vm")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [Vm](#vm) |  |
| [VmSnapshot](#vmsnapshot) |  |

---

## Types

### Vm

```luau
type Vm = {
	vmId: string,
	backendId: string,
	mode: string,
	dom: string,
	sessionGuid: string?,
	placeId: number,
	gameName: string,
	connected: boolean,
	activeRuns: number,
	runCode: (opts: run.RunCodeOpts) -> run.RunResult,
}
```

---

### VmSnapshot

```luau
type VmSnapshot = {
	vmId: string,
	backendId: string?,
	mode: string?,
	dom: string?,
	sessionGuid: string?,
	placeId: number?,
	gameName: string?,
	connected: boolean,
	activeRuns: number,
}
```

---
