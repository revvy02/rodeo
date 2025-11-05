# rir3

Execute Luau code inside Roblox Studio and see output in your terminal.

## Overview

Run scripts in Roblox Studio from your command line. All Studio output (prints, warnings, errors) appears in your terminal with color coding. Uses WebSockets to communicate between the CLI and Studio.

## Usage

### Once Mode (One-off execution)

Execute a script once without any setup. Studio opens temporarily and closes after execution.

```bash
# Basic execution with temporary module
rir3 once path/to/script.luau

# Open a specific place file
rir3 once path/to/script.luau --place path/to/place.rbxl

# Use sourcemap for preserved stack traces
rir3 once path/to/script.luau --place path/to/place.rbxl --sourcemap path/to/sourcemap.json
```

**With sourcemap**: Finds the instance path for your script in the sourcemap, clones the actual ModuleScript from the place file, and executes it. This preserves the real instance path in error stack traces.

**Without sourcemap**: Sends the script source directly through WebSocket for execution in a temporary module.

### Serve Mode (Persistent execution)

For running multiple scripts without restarting Studio. Requires one-time setup.

**Setup** (first time only):
```bash
rir3 build
```

**Start server** (terminal 1):
```bash
rir3 serve
```

The serve command creates a server that routes execution requests to any running Studio instance.

**Execute scripts** (terminal 2):
```bash
# Basic execution
rir3 exec path/to/script.luau

# With sourcemap for preserved stack traces
rir3 exec path/to/script.luau --sourcemap path/to/sourcemap.json
```

**With sourcemap**: Finds the instance path for your script in the sourcemap for output preservation, sends the source as a fallback if not found.

**Without sourcemap**: Sends the script source directly to the Studio instance for execution.

## Features

- **Color-coded output**: Prints, warnings, and errors are color-coded in your terminal
- **Sourcemap support**: Preserve instance paths in stack traces using Rojo/Argon sourcemaps
- **Instance cloning**: When using sourcemaps, clones actual ModuleScripts to maintain tree structure
- **Graceful fallbacks**: Falls back to temporary modules if instance not found
- **Full Studio API access**: Scripts have complete access to all Studio APIs

## Writing Scripts

Scripts execute with full access to Studio APIs:

```lua
print("Hello from Studio!")

local part = Instance.new("Part")
part.Parent = workspace

warn("This is a warning")
```
