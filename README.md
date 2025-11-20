# rir3

Provides a roblox studio luau run-time in cli by routing code 
execution to running studio instances via websockets.

## Installation

```bash
pesde add rvy/rir3
```

## Overview

Run scripts in Roblox Studio and see output in your terminal with color-coded prints, warnings, and errors. Uses WebSockets for communication between CLI and Studio.

## Usage

### Once Mode

Execute a script one time. Studio opens temporarily and closes after execution.

```bash
# Basic execution
rir3 once script.luau

# With place file
rir3 once script.luau --place game.rbxl

# With sourcemap (Helps preserve stack traces)
rir3 once script.luau --place game.rbxl --sourcemap sourcemap.json
```

### Serve Mode

For running multiple scripts without restarting Studio.

**Setup** (first time only):
```bash
rir3 build
```

**Start server**:
```bash
rir3 serve
```

**Execute scripts** (in another terminal):
```bash
# Basic execution
rir3 exec script.luau


### Context Targeting

Target specific runtime contexts when using serve mode. Running tests in studio will automatically connect VMs, and `exec` will let you target VMs with flags.

```bash
# Run in Studio edit mode only
rir3 exec script.luau --studio 1 --running 0

# Run in client only
rir3 exec script.luau --client 1

# Run in server only
rir3 exec script.luau --server 1

# Exclude edit mode
rir3 exec script.luau --edit 0
```

**Available environments:**
- `--studio` - Studio environment
- `--server` - Server runtime
- `--client` - Client runtime
- `--edit` - Edit mode (not running)
- `--running` - Play mode (game running)

Omit a flag to match any value. Use `1` to require it, `0` to exclude it.

### Output Redirection

Redirect execution output and return values to files:

```bash
# Save execution output (prints/logs) to file
rir3 once script.luau --output output.txt

# Save return value to file
rir3 exec script.luau --return result.json

# Save both to different files
rir3 once script.luau --output output.txt --return result.json
```

**Available flags:**
- `--output <path>` - Write execution output (prints/logs) to file instead of stdout
- `--return <path>` - Write return value to file (can be combined with `--show-return`)
- `--show-return` - Print return value to stdout (see [Return Values](#return-values))

### Log Filtering

Control which logs are shown in your terminal:

```bash
# Suppress warnings
rir3 once script.luau --no-warn

# Suppress errors (still sets exit code on error)
rir3 exec script.luau --no-error

# Suppress print statements
rir3 once script.luau --no-print

# Suppress all output
rir3 exec script.luau --no-output
```

**Available flags:**
- `--no-warn` - Hide warning messages
- `--no-error` - Hide error messages
- `--no-info` - Hide info messages
- `--no-print` - Hide print statements
- `--no-output` - Disable all output (most efficient)

### Return Values

Scripts can return values. By default, return values are silent (not printed), but you can:
- Print them to stdout with `--show-return`
- Save them to a file with `--return <path>`
- Do both simultaneously

```bash
# Print return value to stdout
rir3 once script.luau --show-return

# Save return value to file
rir3 exec script.luau --return result.json

# Both: save to file AND print to stdout
rir3 once script.luau --return result.json --show-return

# Capture return value in shell (with --show-return)
result=$(rir3 once script.luau --no-output --show-return)
echo "Result: $result"
```

**Example script:**
```lua
-- Calculate and return a value
local sum = 0
for i = 1, 100 do
    sum = sum + i
end

return { sum = sum, count = 100 }
```

**Output (with `--show-return`):**
```
{"sum":5050,"count":100}
```

Return values are JSON-encoded if possible, otherwise converted to string with `tostring()`.

### Hot-Reloaded Execution

By default, rir3 doesn't cache modules or their dependencies. Every execution reflects the most up-to-date code without needing to restart Studio.

**The problem:** Roblox caches `require()` results, so code changes don't take effect until you restart Studio.

**The solution:** rir3 automatically bypasses Roblox's module cache, ensuring your changes are always reflected.

```bash
# Edit config.luau, utils.luau, or any required modules
# Run your script - changes take effect immediately
rir3 exec main.luau

# Edit modules again
# Run again - fresh code every time
rir3 exec main.luau
```

This default behavior is ideal for development, ensuring executions always reflect your latest changes.

**Performance optimization:** If you need faster execution and your modules aren't changing, use `--cache-requires` to enable caching:

```bash
# Enable module caching (faster, but changes won't be reflected)
rir3 exec script.luau --cache-requires
```

## Features

- **Hot-reloaded modules** - Code changes take effect immediately without restarting Studio
- **Color-coded output** - Prints, warnings, and errors appear in your terminal with colors
- **Environment targeting** - Route executions to specific runtime contexts (edit/play, client/server)
- **Log filtering** - Control which log levels are displayed
- **Return values** - Capture script return values via stdout
- **Sourcemap support** - Preserve stack traces using sourcemaps
- **Full Studio API** - Scripts have complete access to all Studio APIs

## Example Script

```lua
print("Hello from Studio!")

local part = Instance.new("Part")
part.Parent = workspace

warn("Part created in workspace")
```
