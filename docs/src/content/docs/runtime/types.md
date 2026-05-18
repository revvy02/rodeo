---
title: types
---

> _This page is auto-generated from `rodeo-pkg/src/types.luau`._

```luau
local types = require("@rodeo-pkg/types")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [DirectoryEntry](#directoryentry) |  |
| [FileMetadata](#filemetadata) |  |
| [ProcessHandle](#processhandle) |  |
| [ProcessResult](#processresult) |  |
| [ProcessRunOptions](#processrunoptions) |  |
| [StdioKind](#stdiokind) |  |
| [StreamHandle](#streamhandle) |  |

---

## Types

### DirectoryEntry

```luau
type DirectoryEntry = runtime.FsDirEntry
```

---

### FileMetadata

```luau
type FileMetadata = runtime.FsStatResponse
```

---

### ProcessHandle

```luau
type ProcessHandle = {
	__rodeo_pid: string,
	stdin: StreamHandle?,
	stdout: StreamHandle?,
	stderr: StreamHandle?,
}
```

---

### ProcessResult

```luau
type ProcessResult = runtime.ProcessRunResponse
```

---

### ProcessRunOptions

```luau
type ProcessRunOptions = {
	cwd: string?,
	stdio: StdioKind?,
	stdin: StdioKind?,
	stdout: StdioKind?,
	stderr: StdioKind?,
	env: { [string]: string }?,
}
```

---

### StdioKind

```luau
type StdioKind = "default" | "piped" | "inherit" | "none" | "tee"
```

---

### StreamHandle

```luau
type StreamHandle = {
	__handle: string,
}
```

---
