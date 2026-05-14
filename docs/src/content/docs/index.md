---
title: rodeo
description: Automation tool for Roblox Studio. Execute code in any Studio environment, drive Studio from your terminal.
---

`rodeo` is an automation tool for Roblox Studio. It lets you execute code in any Studio environment and control Studio from your terminal, with a developer experience closer to a language runtime than a build tool.

## Install

```bash
mise use ubi:revvy02/rodeo
# or
rokit add revvy02/rodeo
```

## Quickstart

```bash
# 1. Install the companion plugin into Studio. (One-time.)
rodeo plugin

# 2. Open Studio (any place). The plugin auto-connects to localhost:44872.

# 3. Start the rodeo server.
rodeo serve

# 4. Run scripts in another terminal.
rodeo run --source 'print("hi from studio")'
```

## Where to go next

- **[CLI reference](/rodeo/cli/)** — every subcommand and flag, generated from the source.
- **[Luau API](/rodeo/api/)** — drive rodeo programmatically from Lune or Lute.
- **[@rodeo runtime](/rodeo/runtime/)** — the `fs`, `io`, `stream`, `process`, and `roblox` modules your scripts get inside Studio.
