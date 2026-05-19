---
title: studio
---

```luau
local studio = require("@rodeo-client-lune/studio")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

## Summary

| Entry | Description |
| :--- | :--- |
| [MultiplayerTestClient](#multiplayertestclient) |  |
| [MultiplayerTestServer](#multiplayertestserver) |  |
| [OpenFileOpts](#openfileopts) |  |
| [OpenOpts](#openopts) |  |
| [OpenPlaceOpts](#openplaceopts) |  |
| [SaveResult](#saveresult) |  |
| [StartMultiplayerTestOpts](#startmultiplayertestopts) |  |
| [Studio](#studio) |  |
| [StudioBackend](#studiobackend) |  |

---

## Types

### MultiplayerTestClient

```luau
type MultiplayerTestClient = vmMod.Vm & {
	disconnect: () -> (),
}
```

---

### MultiplayerTestServer

```luau
type MultiplayerTestServer = vmMod.Vm & {
	connectClient: () -> MultiplayerTestClient,
	close: () -> (),
}
```

---

### OpenFileOpts

```luau
type OpenFileOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}
```

---

### OpenOpts

```luau
type OpenOpts = {
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}
```

---

### OpenPlaceOpts

```luau
type OpenPlaceOpts = {
	placeId: number,
	fflags: { string }?,
	background: boolean?,
	profile: boolean?,
	logs: string?,
	noHud: boolean?,
}
```

---

### SaveResult

```luau
type SaveResult = {
	saved: boolean,
	path: string?,
	error: string?,
}
```

---

### StartMultiplayerTestOpts

```luau
type StartMultiplayerTestOpts = {
	placeFile: string?,
	placeId: number?,
	fflags: { string }?,
	profile: boolean?,
	runId: string?,
	noHud: boolean?,
}
```

---

### Studio

```luau
type Studio = {
	sessionGuid: string,
	backendId: string,
	editVm: vmMod.Vm,
	serverVm: vmMod.Vm?,
	clientVm: vmMod.Vm?,
	setMode: (mode: string) -> (),
	getMode: () -> string,
	save: () -> SaveResult,
	close: () -> (),
	getVms: () -> { vmMod.Vm },
}
```

---

### StudioBackend

```luau
type StudioBackend = {
	id: string,
	name: string,
	open: (opts: OpenOpts?) -> Studio,
	openPlace: (opts: OpenPlaceOpts) -> Studio,
	openFile: (path: string, opts: OpenFileOpts?) -> Studio,
	startMultiplayerTest: (opts: StartMultiplayerTestOpts?) -> MultiplayerTestServer,
}
```

---
