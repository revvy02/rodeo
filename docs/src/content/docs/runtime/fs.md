---
title: fs
---

```luau
local fs = require("@rodeo/fs")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

## Summary

| Entry | Description |
| :--- | :--- |
| [DirectoryEntry](#directoryentry) | Name + type pair returned by `listdir` for each child of a directory. |
| [FileMetadata](#filemetadata) | Metadata for a filesystem entry — size, type, timestamps. Returned by `stat`. |
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

## Types

### DirectoryEntry

Name + type pair returned by `listdir` for each child of a directory.

```luau
type DirectoryEntry = runtime.FsDirEntry
```

---

### FileMetadata

Metadata for a filesystem entry — size, type, timestamps. Returned by `stat`.

```luau
type FileMetadata = runtime.FsStatResponse
```

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
(path: string) -> { DirectoryEntry }
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
(path: string, mode: string?) -> stream.StreamHandle
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
(path: string) -> FileMetadata
```

---

### fs.type

Returns the type of the entry at `path` as a string — e.g. `"file"`, `"dir"`.

```luau
(path: string) -> string
```

---
