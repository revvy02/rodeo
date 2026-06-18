---
name: rbx-debug
description: Programmatically add breakpoints and inspect thread information to debug Roblox Studio games via MCP, plugins, or command scripts. Use as a more robust tool to investigate scripting bugs or verify script behavior beyond static analysis.
---

# Roblox Studio Debugging with rbx-debug Skill

## When to Use

- Use when debugging scripting bugs that cannot be solved with static analysis or print debugging. Examples: time sensitive behavior, rapidly changing runtime state, adding/removing debugging info without stopping a playtest.  
- Use to confirm changes are correct by verifying underlying script state.

## Quick Start

`ScriptDebuggerService` exposes the Roblox Luau debugger. It provides programmatic breakpoint management, execution control, and runtime inspection.

**Security:** Plugin-level security. Usable by plugins, command scripts, and AI agents via MCP. Not available in regular game scripts.

```lua
local debugger = game:GetService("ScriptDebuggerService")
```

## Core Workflow

The intended pattern is to set breakpoints and define an `OnStopped` callback (one per play DM) that performs thread inspection:

1. **Clear existing breakpoints** with `ClearBreakpoints()`
2. **Set new breakpoints/logpoints** in the edit DM and configure exception breaks if needed
3. **Start play mode**
4. **Set `OnStopped` on each play DM** (server/client) once the playtest is running — `OnStopped` does **not** propagate from the edit DM, so it must be installed on each play DM directly. Inspect threads, stack, and variables inside the callback, then return a resume action.

The late-set behavior covers the gap if a breakpoint fires before you've installed `OnStopped`: setting it while the DM is already stopped (and the previous value was `nil`) runs the callback immediately. See "OnStopped Late-Set Behavior" below.

State inspection (`GetThreads`, `GetStackTrace`, `GetRootVariables`, `GetVariables`, `Evaluate`) is only meaningful while the DataModel is paused, which in practice means "inside the `OnStopped` callback."

> **Alternative:** logpoints (`LogMessage` + `ContinueExecution = true`) write to the Studio output without pausing, so a caller that can read the output can poll for state instead of using `OnStopped`. Prefer `OnStopped` when you need richer inspection.

---

## Important Behavioral Notes

### OnStopped is per-DataModel
The `OnStopped` callback is unique to the DataModel it was set on. It does **not** propagate from the edit DM to the play DMs (server/client) when a playtest starts, and changes to it do not replicate. After the playtest is running, install `OnStopped` on each play DM directly — setting it on the edit DM has no effect on play DMs.

### OnStopped Late-Set Behavior
If `OnStopped` is set while the DataModel is already stopped at a breakpoint **and the previous value was nil**, the callback runs immediately. You can attach a handler after a breakpoint has already been hit and still react to it.

### OnStopped Error / Missing Return Handling
If the `OnStopped` callback throws an error or does not return a resume action, the game **resumes by default**. Always return an explicit `Enum.DebuggerResumeType`, and avoid uncaught errors inside the callback.

### Getter Methods When Not Stopped
`GetThreads`, `GetRootVariables`, and `GetVariables` return **empty results** when:
1. The DataModel is not currently stopped at a breakpoint or exception.
2. The DataModel is stopped as a result of a `Pause()` call.

`GetRootVariables` and `GetVariables` should always be passed valid frame IDs and variable references.

### Breakpoint Propagation (Play vs Edit DataModel)
- **Play mode DataModel:** setting/removing a breakpoint propagates to script clones in the same DataModel and to corresponding scripts in other DataModels (e.g., server/client).
- **Edit DataModel:** breakpoints are set on the specific script instance and do not propagate to clones, but they **do** propagate to corresponding scripts in play DMs at the start of a playtest.
- **Recommendation:** call `ClearBreakpoints()` before setting new ones in bulk to avoid leftover breakpoints causing unexpected stops.

### Miscellaneous Notes
- Calling `Pause()` while already stopped at a breakpoint has no effect.
- Avoid uncaught errors in any lambda attached to the `Resumed` event.

---

## API Reference

### Breakpoint Management

#### `AddBreakpoint(scriptInstance: Instance, breakpoint: ScriptBreakpoint) -> ScriptBreakpointResult`

Adds a breakpoint to a script. If a breakpoint already exists on the same script and line, its data is replaced.

**ScriptBreakpoint fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Line` | number | yes | 1-based line number |
| `Enabled` | bool | no | Whether the breakpoint is active (default: true) |
| `Condition` | string | no | Luau expression that must be truthy to pause (e.g., `"health < 10"`) |
| `LogMessage` | string | no | Message logged when the breakpoint is hit. See "LogMessage syntax" below. |
| `ContinueExecution` | boolean | no | If true, the DataModel does not pause when the breakpoint is hit. Independent of `LogMessage`. (default: false) |

**LogMessage syntax:** the string is parsed as a comma-separated list of Luau expressions, evaluated in the breakpoint's scope, and concatenated print-style with spaces between segments. String literals are quoted; bare identifiers reference live values. Example: `"'count is', count"` produces output like `count is 7`.

**Logpoint behavior:** `LogMessage` and `ContinueExecution` are independent flags. Combine them as needed:

| `LogMessage` | `ContinueExecution` | Result |
|--------------|---------------------|--------|
| set | `true` | Logs when hit; does not pause (logpoint) |
| set | `false` / unset | Logs when hit; pauses |
| unset | `true` | Does not log; does not pause (effectively a no-op) |
| unset | `false` / unset | Plain breakpoint; pauses |

**Returns** `ScriptBreakpointResult`:
| Field | Type | Description |
|-------|------|-------------|
| `Verified` | boolean | Whether the breakpoint was placed successfully |
| `Line` | number | Line the breakpoint was placed on |
| `Message` | string? | Optional explanation if `Verified` is false |

**Errors:** Luau error if the script instance or breakpoint argument is invalid.

```lua
local debugger = game:GetService("ScriptDebuggerService")
local script = game:GetService("ServerScriptService").MainScript

local bp = debugger:AddBreakpoint(script, { Line = 10 })
print(bp.Verified, bp.Line)

-- Conditional breakpoint
debugger:AddBreakpoint(script, { Line = 20, Condition = "count > 100" })

-- Logpoint (logs without pausing)
debugger:AddBreakpoint(script, {
    Line = 30,
    LogMessage = "'a is', a, '; b is', b",
    ContinueExecution = true,
})
```

#### `RemoveBreakpoint(scriptInstance: Instance, line: number) -> bool`

Removes the breakpoint on the given script and line. Returns false if no breakpoint exists on the line (no-op).

**Errors:** Luau error if the script instance or line number is invalid.

```lua
local removed = debugger:RemoveBreakpoint(script, 10)
```

#### `ClearBreakpoints() -> void`

Removes all known breakpoints across all scripts. Never errors.

```lua
debugger:ClearBreakpoints()
```

### Exception Configuration

#### `SetExceptionBreakMode(breakMode: Enum.DebugBreakModeType) -> void`

Controls when the debugger pauses on exceptions. Sets the break mode on **all** DataModels.

| Mode | Behavior |
|------|----------|
| `DebugBreakModeType.Never` | Never break on exceptions |
| `DebugBreakModeType.Always` | Break on all exceptions |
| `DebugBreakModeType.Unhandled` | Break only on exceptions not caught by pcall/xpcall |

```lua
debugger:SetExceptionBreakMode(Enum.DebugBreakModeType.Unhandled)
```

### Execution Control

#### `Pause() -> void`

Requests the debugger to pause at the next safe point. Asynchronous — returns immediately. When the thread pauses, `OnStopped` fires with reason `Pause`. Has no effect if already stopped.

**Constraint:** only meaningful when the DataModel is running during a playtest.

```lua
debugger:Pause()
```

### Thread & Stack Inspection

These methods should be called when the DataModel is stopped, typically inside `OnStopped`. If called when the DataModel is not stopped, they return empty results.

#### `GetThreads() -> {ScriptDebugThread}`

Returns all paused Luau threads.

| Field | Type | Description |
|-------|------|-------------|
| `Id` | number | Thread identifier (use with `GetStackTrace`, stepping) |
| `Name` | string | Human-readable name of the script |

```lua
debugger.OnStopped = function(info)
    local threads = debugger:GetThreads()
    for _, thread in threads do
        print("Thread", thread.Id, thread.Name)
    end
end
```

#### `GetStackTrace(threadId: number, startFrame: number?) -> DebugStackTraceResult`

Returns the call stack for a paused thread, ordered innermost (current) to outermost.

**Returns** `DebugStackTraceResult`:
- `Frames`: array of `DebugStackFrame` (`Id`, `Name`, `ScriptPath`, `Line`)
- `TotalFrames`: number? (total frame count for pagination)

Use `startFrame` (1-based) for paginated retrieval.

**Errors:** Luau error if `threadId` or `startFrame` is invalid.

```lua
debugger.OnStopped = function(info)
    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    for i, frame in stack.Frames do
        print(i, frame.Name, frame.ScriptPath, "line", frame.Line)
    end
end
```

### Variable Inspection

#### `GetRootVariables(frameId: number) -> {ScriptVariable}`

Returns the root variables (locals, upvalues, globals) for a stack frame.

**Errors:** Luau error if `frameId` is invalid. Returns empty if not stopped.

#### `GetVariables(variablesReference: number) -> {ScriptVariable}`

Drills into structured variables (tables, Instances). Pass a `VariablesReference` from a previous call to `GetRootVariables` or `GetVariables`.

**ScriptVariable fields:**
| Field | Type | Description |
|-------|------|-------------|
| `Name` | string | Variable name or table key |
| `Value` | string | String representation of the value |
| `Type` | string | Luau type (`"number"`, `"string"`, `"table"`, `"Instance"`, etc.) |
| `Scope` | ScriptVariableScope | `Local`, `Upvalue`, or `Global` (children inherit parent's scope) |
| `VariablesReference` | number | If > 0, call `GetVariables()` with this to get children. 0 = leaf. |

```lua
debugger.OnStopped = function(info)
    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    local vars = debugger:GetRootVariables(stack.Frames[1].Id)

    for _, v in vars do
        print(v.Name, "=", v.Value, "(" .. v.Type .. ")")
        if v.VariablesReference > 0 then
            local children = debugger:GetVariables(v.VariablesReference)
            for _, child in children do
                print("  " .. child.Name, "=", child.Value)
            end
        end
    end
end
```

### Expression Evaluation

#### `Evaluate(expression: string, frameId: number?) -> ScriptEvaluateResult`

Evaluates a Luau expression in a stack frame's context (or globally if no `frameId` is provided).

**Returns** `ScriptEvaluateResult`:
| Field | Type | Description |
|-------|------|-------------|
| `Result` | string | String representation of the result |
| `Type` | string | Result type |
| `VariablesReference` | number | If > 0, drill into with `GetVariables()` |

**Errors:** Luau error if the expression has a syntax error or `frameId` is invalid. Returns empty if not stopped.

```lua
debugger.OnStopped = function(info)
    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    local result = debugger:Evaluate("a", stack.Frames[1].Id)
    print("a:", result.Result, result.Type)
end
```

### OnStopped Callback

#### `OnStopped = function(info: ScriptDebugStopped) -> (Enum.DebuggerResumeType, number?)`

The primary mechanism for reacting to debugger pauses. Set this to a function. Only one `OnStopped` per DataModel is allowed, and it must be set on each DataModel where you expect a pause.

**Recommended:** once a playtest is running, install `OnStopped` on each play DataModel (server/client) directly. It is not inherited from the edit DM. If a breakpoint fires before you've installed it, the late-set behavior still runs your callback the moment you set it (provided the previous value was `nil`).

**`ScriptDebugStopped` payload:**
| Field | Type | Description |
|-------|------|-------------|
| `Reason` | ScriptStoppedReason | `Breakpoint`, `Exception`, `Pause`, `Step`, or `Entry` |
| `ThreadIds` | {number} | Threads that stopped |
| `ExceptionText` | string? | Error message (when `Reason` is `Exception`) |

**Return values** (multi-return — not a table):
| Position | Type | Description |
|----------|------|-------------|
| 1 | `Enum.DebuggerResumeType` | `Resume`, `StepInto`, `StepOut`, or `StepOver` |
| 2 | `number?` | Required for step actions — which thread to step |

If the callback returns nothing or throws, `Resume` is assumed.

```lua
-- Resume after inspecting
debugger.OnStopped = function(info)
    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    print("Stopped at:", stack.Frames[1].Name, "line", stack.Frames[1].Line)
    return Enum.DebuggerResumeType.Resume
end

-- Step over repeatedly
debugger.OnStopped = function(info)
    return Enum.DebuggerResumeType.StepOver, info.ThreadIds[1]
end
```

### Resumed Event

#### `Resumed: RBXScriptSignal` — fires with `(threadIds: {number})`

Fires when a previously paused thread resumes. After this event, all `frameId`s, `VariablesReference`s, and `ScriptVariable` objects from that thread are invalidated. Re-fetch them the next time the DataModel stops if needed.

```lua
debugger.Resumed:Connect(function(threadIds)
    print("Thread", threadIds[1], "resumed")
end)
```

---

## Enums

| Enum | Values |
|------|--------|
| `Enum.DebugBreakModeType` | `Never`, `Always`, `Unhandled` |
| `Enum.DebuggerResumeType` | `StepInto`, `StepOut`, `StepOver`, `Resume` |
| `Enum.ScriptStoppedReason` | `Breakpoint`, `Exception`, `Pause`, `Step`, `Entry` |
| `Enum.ScriptVariableScope` | `Local`, `Upvalue`, `Global` |

## Structs

| Struct | Fields |
|--------|--------|
| `ScriptBreakpoint` | `Line: number`, `Enabled: bool?`, `Condition: string?`, `LogMessage: string?`, `ContinueExecution: boolean?` |
| `ScriptBreakpointResult` | `Verified: boolean`, `Line: number`, `Message: string?` |
| `ScriptEvaluateResult` | `Result: string`, `Type: string`, `VariablesReference: number` |
| `DebugStackFrame` | `Id: number`, `Name: string`, `ScriptPath: string`, `Line: number` |
| `DebugStackTraceResult` | `Frames: {DebugStackFrame}`, `TotalFrames: number?` |
| `ScriptDebugStopped` | `Reason: ScriptStoppedReason`, `ThreadIds: {number}`, `ExceptionText: string?` |
| `ScriptDebugThread` | `Id: number`, `Name: string` |
| `ScriptVariable` | `Name: string`, `Value: string`, `Type: string`, `Scope: ScriptVariableScope`, `VariablesReference: number` |

---

## Constraints & Edge Cases

### OnStopped is Special
**Do not modify the DataModel** (move instances, set properties) inside `OnStopped` — only inspect thread state with `ScriptDebuggerService` methods. Modifying the DataModel results in undefined behavior.

### Parallel Threads
The behavior of this API with parallel Luau is undefined.

---

## Complete Example: Step-Through Testing

```lua
local debugger = game:GetService("ScriptDebuggerService")
local targetScript = game.ServerScriptService.TestScript

debugger:ClearBreakpoints()
debugger:AddBreakpoint(targetScript, { Line = 1 })

-- Set callback on play DMs
local stepCount = 0
debugger.OnStopped = function(info)
    stepCount += 1
    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    local frame = stack.Frames[1]

    print(string.format("Step %d: %s line %d", stepCount, frame.Name, frame.Line))

    if stepCount < 20 then
        return Enum.DebuggerResumeType.StepOver, info.ThreadIds[1]
    end

    return Enum.DebuggerResumeType.Resume
end
```

## Complete Example: Exception Hunting

```lua
local debugger = game:GetService("ScriptDebuggerService")
debugger:SetExceptionBreakMode(Enum.DebugBreakModeType.Unhandled)

-- Set callback on play DMs
debugger.OnStopped = function(info)
    if info.Reason ~= Enum.ScriptStoppedReason.Exception then
        return Enum.DebuggerResumeType.Resume
    end

    print("EXCEPTION:", info.ExceptionText)

    local stack = debugger:GetStackTrace(info.ThreadIds[1])
    for i, frame in stack.Frames do
        print(string.format("  #%d %s (%s:%d)", i, frame.Name, frame.ScriptPath, frame.Line))
    end

    local vars = debugger:GetRootVariables(stack.Frames[1].Id)
    for _, v in vars do
        print(string.format("    %s = %s (%s)", v.Name, v.Value, v.Type))
    end

    return Enum.DebuggerResumeType.Resume
end
```
