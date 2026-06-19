---
title: CLI usage
---

The simplest way to drive rodeo is from the shell.

## Start the server

In one terminal:

```bash
rodeo serve
```

This starts the rodeo server on `localhost:44872` and waits for Studio to connect. Open Studio (any place) and the installed plugin connects automatically.

## Run a one-shot script

In another terminal:

```bash
rodeo run --source 'print("hi from studio")'
```

The script executes inside the connected Studio instance. Output streams back to your terminal.

You can also run a file:

```bash
rodeo run script.luau
```

## Launch a place

`rodeo run` can launch Studio for you:

```bash
# Launch by published place ID
rodeo run --place 12345 --source 'return game.PlaceId'

# Launch a local .rbxl file
rodeo run --place ./my-place.rbxl script.luau
```

Studio launches in the background and the script runs against it. By default rodeo closes the Studio it launched once the run finishes; pass `--detached` to keep it running.

## Launch a detached Studio

Pass `--detached` to spawn a Studio that isn't tied to the `rodeo run` process. Instead of closing the Studio when the script finishes, rodeo leaves it running:

```bash
# Launch a Studio and leave it up after the command exits
rodeo run --place 12345 --detached --source 'print("studio is up")'
```

The command returns, but the Studio stays open and connected to the server, so later `rodeo run` commands can target it without relaunching:

```bash
rodeo run --source 'return game.PlaceId'
```

When you're done, quit the Studio yourself; because it's detached, rodeo won't close it for you.

## Where to go next

See the full [CLI reference](/rodeo/cli/) for every subcommand and flag, or move on to [Runtime usage](/rodeo/getting-started/runtime-usage/) for what scripts can do inside Studio.
