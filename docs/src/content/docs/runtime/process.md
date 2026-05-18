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
| [args](#processargs) | The command-line arguments passed to this rodeo execution after `--`. |
| [create](#processcreate) | Spawns `args` as a child process without waiting. Returns a handle with |
| [cwd](#processcwd) | Returns the current working directory. |
| [env](#processenv) | A read-only view of environment variables visible to this execution. |
| [execpath](#processexecpath) | Returns the path of the running rodeo binary. |
| [exit](#processexit) | Exits the current execution with the given code. |
| [homedir](#processhomedir) | Returns the user's home directory. |
| [kill](#processkill) | Terminates a process started with `create`. |
| [run](#processrun) | Runs `args` (or an existing handle), blocking until completion. Returns |
| [system](#processsystem) | Like `run`, but takes a single shell-style command string. |

---

## Functions and Properties

### process.args

The command-line arguments passed to this rodeo execution after `--`.

```luau
any) :: { string }
```

---

### process.create

Spawns `args` as a child process without waiting. Returns a handle with

stdin/stdout/stderr stream handles for live interaction.

```luau
(args: { string }, options: shared.ProcessRunOptions?) -> shared.ProcessHandle
```

---

### process.cwd

Returns the current working directory.

```luau
() -> string
```

---

### process.env

A read-only view of environment variables visible to this execution.

```luau
any) :: { [string]: string? }
```

---

### process.execpath

Returns the path of the running rodeo binary.

```luau
() -> string
```

---

### process.exit

Exits the current execution with the given code.

```luau
(code: number) -> ()
```

---

### process.homedir

Returns the user's home directory.

```luau
() -> string
```

---

### process.kill

Terminates a process started with `create`.

```luau
(handle: shared.ProcessHandle) -> ()
```

---

### process.run

Runs `args` (or an existing handle), blocking until completion. Returns

captured stdout/stderr and exit code.

```luau
(argsOrHandle: { string } | shared.ProcessHandle, options: shared.ProcessRunOptions?) -> shared.ProcessResult
```

---

### process.system

Like `run`, but takes a single shell-style command string.

```luau
(command: string, options: shared.ProcessRunOptions?) -> shared.ProcessResult
```

---
