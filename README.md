<p align="center">
  <img src="assets/plugin/logo.png" width="200" />
</p>

# rodeo
Provides a roblox studio luau run-time in cli by routing code 
execution to running studio instances via websockets.

## Features
- **Hot-reloaded modules** - Code changes take effect immediately without restarting Studio
- **Color-coded output** - Prints, warnings, and errors appear in your terminal with colors
- **Environment targeting** - Route executions to specific runtime contexts (edit/play, client/server)
- **Log filtering** - Control which log levels are displayed
- **Return values** - Capture script return values via stdout
- **Sourcemap support** - Auto-detects `sourcemap.json` to preserve stack traces
- **Full Studio API** - Scripts have complete access to all Studio APIs

## Installation

### via pesde

```bash
pesde add rvy/rodeo
```

### via mise

```bash
mise use ubi:revvy02/rodeo
```

### via rokit

```bash
rokit add revvy02/rodeo
```

## Usage

### Serve Mode

For running multiple scripts without restarting Studio.

**Setup** (first time only):
```bash
rodeo plugin
```

**Start server**:
```bash
rodeo serve
```

**Run scripts** (in another terminal):
```bash
# Basic execution
rodeo exec script.luau

# Run from .rodeo/ directory
rodeo exec mytest              # runs .rodeo/mytest.luau
```

### VM Targeting

Target specific runtime instances when using serve mode. Running tests in studio will automatically connect VMs, and `run` will let you target VMs with flags. This lets you run code specifically in play mode, test mode, play test server, play test client, etc, by targeting RunService flags.

```bash
# Run in Studio edit mode only
rodeo exec script.luau --studio 1 --running 0

# Run in client only
rodeo exec script.luau --client 1

# Run in server only
rodeo exec script.luau --server 1

# Exclude edit mode
rodeo exec script.luau --edit 0
```

**Available environments:**
- `--studio` - Studio environment
- `--server` - Server runtime
- `--client` - Client runtime
- `--edit` - Edit mode (not running)
- `--running` - Play mode (game running)

Omit a flag to match any value. Use `1` to require it, `0` to exclude it.

### Execution Context

Control which runtime context your code executes in. This allows you to use direct references and access modules as if your code were running normally on the client or server.

```bash
# Execute in server context (Script)
rodeo exec script.luau --context server

# Execute in client context (LocalScript)
rodeo exec script.luau --context client

# Execute in plugin context (default)
rodeo exec script.luau --context plugin
```

**Available contexts:**
- `plugin` (default)
- `server` - Runs as a Script
- `client` - Runs as a LocalScript

Example using server context to access server-only APIs:

```lua
-- @rodeo exec --context server
local ServerStorage = game:GetService("ServerStorage")
local myModule = require(ServerStorage.Modules.MyServerModule)
return myModule:doSomething()
```

### Script Arguments

Pass arguments to scripts using the `--` separator:

```bash
# Pass arguments to script
rodeo exec script.luau -- arg1 arg2 "arg with spaces"

# Works with inline source too
rodeo exec -s 'return function(args) return args end' -- hello world
```

Modules that return a function receive the arguments:

```lua
return function(args)
    print(args[1])  -- "arg1"
    print(args[2])  -- "arg2"
    return args
end
```

Modules that don't return a function work as before - no breaking changes.

### Directives

Embed default flags directly in your script files using the `@rodeo` directive:

```lua
-- @rodeo exec --show-return --context server
return function(args)
    return { result = "executed on server" }
end
```

You can also specify default arguments in directives:

```lua
-- @rodeo exec --show-return -- default-arg1 default-arg2
return function(args)
    return args  -- uses directive args if no CLI args provided
end
```

CLI flags and arguments override directive defaults:

```bash
# Uses directive defaults
rodeo exec script.luau

# Override context from directive
rodeo exec script.luau --context plugin

# Override args from directive (use -- with nothing to pass empty args)
rodeo exec script.luau -- custom-arg
rodeo exec script.luau --   # explicitly empty args
```

### Custom Port Configuration

By default, rodeo uses port 44872 for serve mode and 44873 for once mode. You can customize the port number if needed:

```bash
# Start server on custom port
rodeo serve --port 8080

# Run script on custom port server
rodeo exec script.luau --port 8080

# One-time execution on custom port
rodeo once script.luau --port 9000
```

**Available commands with `--port`:**
- `rodeo serve --port <number>` - Start server on custom port (default: 44872)
- `rodeo exec --port <number>` - Connect to server on custom port (default: 44872)
- `rodeo once --port <number>` - Run ephemeral server on custom port (default: 44873)

### Output Redirection

Redirect execution output and return values to files:

```bash
# Save execution output (prints/logs) to file
rodeo once script.luau --output output.txt

# Save return value to file
rodeo exec script.luau --return result.json

# Save both to different files
rodeo once script.luau --output output.txt --return result.json
```

**Available flags:**
- `--output <path>` - Write execution output (prints/logs) to file instead of stdout
- `--return <path>` - Write return value to file (can be combined with `--show-return`)
- `--show-return` - Print return value to stdout (see [Return Values](#return-values))

### Log Filtering

Control which logs are shown in your terminal:

```bash
# Suppress warnings
rodeo once script.luau --no-warn

# Suppress errors (still sets exit code on error)
rodeo exec script.luau --no-error

# Suppress print statements
rodeo once script.luau --no-print

# Suppress all output
rodeo exec script.luau --no-output
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
rodeo once script.luau --show-return

# Save return value to file, 
# You can also have it generate a .luau file that returns a table with the json data
rodeo exec script.luau --return result.luau

# Both: save to file AND print to stdout
rodeo once script.luau --return result.json --show-return

# Capture return value in shell (with --show-return)
result=$(rodeo once script.luau --no-output --show-return)
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

### Module Caching

By default, rodeo ensures fresh code on every execution by cloning module instances before running, and renaming originals. This bypasses Roblox's require cache without using loadstring or setfenv (which cause deoptimization). Static requires work reliably; dynamic requires may have edge cases.

Use `--cache-requires` to enable standard Roblox caching behavior for better performance when modules aren't changing.

## Output Example
<p align="center">
  <img src="assets/docs/output.png" width="100%" />
</p>