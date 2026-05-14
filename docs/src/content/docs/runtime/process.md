---
title: process
---

> _This page is auto-generated from `rodeo-pkg/src/process.luau`._

```luau
local process = require("@rodeo-pkg/process")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [Process](#process) |  |

---

## Types

### Process

```luau
type Process = {
	args: { string },
	env: { [string]: string? },
	cwd: () -> string,
	homedir: () -> string,
	execpath: () -> string,
	exit: (code: number) -> (),
	run: (argsOrHandle: { string } | shared.ProcessHandle, options: shared.ProcessRunOptions?) -> shared.ProcessResult,
	system: (command: string, options: shared.ProcessRunOptions?) -> shared.ProcessResult,
	create: (args: { string }, options: shared.ProcessRunOptions?) -> shared.ProcessHandle,
	kill: (handle: shared.ProcessHandle) -> (),
}
```

---
