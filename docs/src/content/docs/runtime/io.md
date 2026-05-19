---
title: io
---

```luau
local io = require("@rodeo/io")
```
:::caution
These APIs are not finalized and may change in backwards incompatible ways.
:::

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
any) :: stream.StreamHandle
```

---

### io.stdin

Standard input stream handle. Pass to `stream.read` to read from stdin.

```luau
any) :: stream.StreamHandle
```

---

### io.stdout

Standard output stream handle. Pass to `stream.write` to write to stdout.

```luau
any) :: stream.StreamHandle
```

---
