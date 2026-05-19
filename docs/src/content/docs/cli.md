---
title: CLI reference
description: Every rodeo subcommand and flag (auto-generated).
---

## `rodeo`

Command-line interface for Roblox Studio

**Usage:** `rodeo [OPTIONS] <COMMAND>`

###### **Subcommands:**

* `serve` — Start persistent server (no Studio launch — use `run --place` for that)
* `run` — Run a script in Studio
* `ps` — List active processes
* `kill` — Kill a running process
* `save` — Save the Studio place
* `plugin` — Build and install the rodeo plugin
* `setup` — Generate type definitions and configure .luaurc
* `mcp` — Start MCP server for AI agent integration

###### **Options:**

* `-v`, `--verbose` — Enable debug output



## `rodeo serve`

Start persistent server (no Studio launch — use `run --place` for that)

**Usage:** `rodeo serve [OPTIONS]`

###### **Options:**

* `--port <PORT>` — Port number for server
* `--master` — Run as master only (central orchestrator)
* `--studio` — Run as studio backend only (connects to master)
* `--master-host <MASTER_HOST>` — Master host to connect to (for --studio)

  Default value: `localhost`
* `--master-port <MASTER_PORT>` — Master port to connect to (for --studio)
* `--ppid <PPID>` — Parent PID — exit when this process dies



## `rodeo run`

Run a script in Studio

**Usage:** `rodeo run [OPTIONS] [SCRIPT] [-- <SCRIPT_ARGS>...]`

###### **Arguments:**

* `<SCRIPT>` — Path to the script to execute, or '-' for stdin
* `<SCRIPT_ARGS>` — Script arguments (passed after --)

###### **Options:**

* `-s`, `--source <SOURCE>` — Execute source code passed as string
* `--sourcemap <SOURCEMAP>` — Path to sourcemap.json for instance resolution
* `--output <OUTPUT>` — Path to file for execution output (prints/logs)
* `--return <RETURN_FILE>` — Path to file for return value JSON
* `--show-return` — Print return value to stdout
* `--target <TARGET>` — Target: mode:dom[:identity] (e.g. edit:plugin, test:server, play:client:plugin)
* `--studio <STUDIO>` — Studio instance to target (id, name, or "active")
* `--no-warn` — Disable warning output
* `--no-error` — Disable error output
* `--no-info` — Disable info output
* `--no-print` — Disable print statements
* `--no-output` — Disable all output
* `--cache-requires` — Enable module caching (skip reloader for better performance)
* `--ppid <PPID>` — Parent PID — exit when this process dies
* `--host <HOST>` — Host of running server

  Default value: `localhost`
* `--port <PORT>` — Port number of running server

  Default value: `44872`
* `--place <PLACE>` — Launch Studio: empty (no value), place ID (number), or file path (.rbxl/.rbxlx)
* `--job <JOB>` — Target a specific server instance by job ID (gameInstanceId)
* `--vm <VM>` — Target a specific VM directly by ID
* `--backend <BACKEND>` — Target a specific backend device (by name or ID)
* `--place.universe <UNIVERSE_ID>` — Universe ID (resolved from place ID if omitted)
* `--focus` — Bring Studio to the foreground on launch (default: background)
* `--detached` — Keep Studio/Player running after rodeo exits
* `--no-hud` — Strip Studio UI panels (Explorer/Properties/Toolbox/Output/etc.) for a minimal launch. Applies only to the Studio rodeo launches; restored on exit
* `--profile <PROFILE>` — Enable microprofiler auto-capture and collect dumps (optional: output directory)
* `--logs <LOGS>` — Collect Studio log output for this run (optional: output directory)
* `--save <SAVE>` — Save Studio place on exit, optionally to a specific path
* `--fflag.override <KEY=VALUE>` — Set FFlag override (Key=Value, repeatable)
* `--fflag.file <PATH>` — Load FFlag overrides from a JSON file



## `rodeo ps`

List active processes

**Usage:** `rodeo ps [OPTIONS]`

###### **Options:**

* `--host <HOST>` — Host of running server

  Default value: `localhost`
* `--port <PORT>` — Port number of running server

  Default value: `44872`



## `rodeo kill`

Kill a running process

**Usage:** `rodeo kill [OPTIONS] <ID>`

###### **Arguments:**

* `<ID>` — Process ID to kill

###### **Options:**

* `--host <HOST>` — Host of running server

  Default value: `localhost`
* `--port <PORT>` — Port number of running server

  Default value: `44872`



## `rodeo save`

Save the Studio place

**Usage:** `rodeo save [OPTIONS]`

###### **Options:**

* `--out <OUT>` — Copy saved file to this output path
* `--host <HOST>` — Host of running server

  Default value: `localhost`
* `--port <PORT>` — Port number of running server

  Default value: `44872`



## `rodeo plugin`

Build and install the rodeo plugin

**Usage:** `rodeo plugin`



## `rodeo setup`

Generate type definitions and configure .luaurc

**Usage:** `rodeo setup`



## `rodeo mcp`

Start MCP server for AI agent integration

**Usage:** `rodeo mcp [OPTIONS]`

###### **Options:**

* `--host <HOST>` — Host of running server

  Default value: `localhost`
* `--port <PORT>` — Port number of running server

  Default value: `44872`



<hr/>

<small><i>
    This document was generated automatically by
    <a href="https://crates.io/crates/clap-markdown"><code>clap-markdown</code></a>.
</i></small>