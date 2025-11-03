# rir3

Execute Luau code inside Roblox Studio and see output in your terminal.

## What it does

Run scripts in Roblox Studio from your command line. All Studio output (prints, warnings, errors) appears in your terminal with color coding.

Uses WebSockets to communicate between the CLI and Studio. `rir3 once` is functionally identical to [run-in-roblox](https://github.com/rojo-rbx/run-in-roblox) and can serve as a drop-in replacement.

## Plans
File path + sourcemap reconciliation in execution for accurate stack traces
Output timestamps + better output formatting
Clickable output
Output syncing (i.e. NexusSync)
Cloud execution

## Usage

### One-off execution

Run a script once (no setup needed):

```bash
rir3 once demo/hello.luau
```

Optionally specify a place file:
```bash
rir3 once demo/hello.luau demo/Place.rbxlx
```

### Persistent mode

For running multiple scripts without restarting Studio:

1. Build the plugin (once):
```bash
rir3 build
```

2. Start the server (terminal 1):
```bash
rir3 serve
```

3. Execute scripts (terminal 2):
```bash
rir3 exec demo/hello.luau
```

## Writing scripts

Scripts have full access to Studio APIs:

```lua
print("Hello from Studio!")

local part = Instance.new("Part")
part.Parent = workspace

warn("This is a warning")
```
