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
| [copy](#fscopy) | Copies the file at `src` to `dest`. Overwrites `dest` if it exists. |
| [exists](#fsexists) | Returns `true` if a file or directory exists at `path`. |
| [listdir](#fslistdir) | Returns directory entries (name + type) for the immediate children of `path`. |
| [mkdir](#fsmkdir) | Creates a directory at `path`. |
| [open](#fsopen) | Opens the file at `path` in `mode` (`"r"`, `"w"`, `"a"`, etc.). Returns a |
| [remove](#fsremove) | Removes the file at `path`. |
| [rmdir](#fsrmdir) | Removes the directory at `path`. Fails if non-empty. |
| [stat](#fsstat) | Returns metadata (size, type, timestamps) for the file or directory at `path`. |
| [type](#fstype) | Returns the type of the entry at `path` as a string — e.g. `"file"`, `"dir"`. |

---

## Functions and Properties

### fs.copy

Copies the file at `src` to `dest`. Overwrites `dest` if it exists.

```luau
(src: string, dest: string) -> ()
```

---

### fs.exists

Returns `true` if a file or directory exists at `path`.

```luau
(path: string) -> boolean
```

---

### fs.listdir

Returns directory entries (name + type) for the immediate children of `path`.

```luau
(path: string) -> { shared.DirectoryEntry }
```

---

### fs.mkdir

Creates a directory at `path`.

```luau
(path: string) -> ()
```

---

### fs.open

Opens the file at `path` in `mode` (`"r"`, `"w"`, `"a"`, etc.). Returns a

stream handle usable with `stream.read`, `stream.write`, `stream.close`.

```luau
(path: string, mode: string?) -> shared.StreamHandle
```

---

### fs.remove

Removes the file at `path`.

```luau
(path: string) -> ()
```

---

### fs.rmdir

Removes the directory at `path`. Fails if non-empty.

```luau
(path: string) -> ()
```

---

### fs.stat

Returns metadata (size, type, timestamps) for the file or directory at `path`.

```luau
(path: string) -> shared.FileMetadata
```

---

### fs.type

Returns the type of the entry at `path` as a string — e.g. `"file"`, `"dir"`.

```luau
(path: string) -> string
```

---
