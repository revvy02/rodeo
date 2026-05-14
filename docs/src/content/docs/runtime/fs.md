---
title: fs
---

> _This page is auto-generated from `rodeo-pkg/src/fs.luau`._

```luau
local fs = require("@rodeo-pkg/fs")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [Fs](#fs) |  |

---

## Types

### Fs

```luau
type Fs = {
	open: (path: string, mode: string?) -> shared.StreamHandle,
	remove: (path: string) -> (),
	stat: (path: string) -> shared.FileMetadata,
	type: (path: string) -> string,
	mkdir: (path: string) -> (),
	exists: (path: string) -> boolean,
	copy: (src: string, dest: string) -> (),
	listdir: (path: string) -> { shared.DirectoryEntry },
	rmdir: (path: string) -> (),
}
```

---
