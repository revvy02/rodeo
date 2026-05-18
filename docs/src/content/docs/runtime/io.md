---
title: io
---

> _This page is auto-generated from `rodeo-pkg/src/io.luau`._

```luau
local io = require("@rodeo-pkg/io")
```
## Summary

| Entry | Description |
| :--- | :--- |
| [read](#ioread) | Reads a line from stdin (blocking). Returns the line without trailing newline. |
| [stderr](#iostderr) | Standard error stream handle. Pass to `stream.write` to write to stderr. |
| [stdin](#iostdin) | Standard input stream handle. Pass to `stream.read` to read from stdin. |
| [stdout](#iostdout) | Standard output stream handle. Pass to `stream.write` to write to stdout. |

---

## Functions and Properties

### io.read

Reads a line from stdin (blocking). Returns the line without trailing newline.

```luau
() -> string
```

---

### io.stderr

Standard error stream handle. Pass to `stream.write` to write to stderr.

```luau
any) :: shared.StreamHandle
```

---

### io.stdin

Standard input stream handle. Pass to `stream.read` to read from stdin.

```luau
any) :: shared.StreamHandle
```

---

### io.stdout

Standard output stream handle. Pass to `stream.write` to write to stdout.

```luau
any) :: shared.StreamHandle
```

---
