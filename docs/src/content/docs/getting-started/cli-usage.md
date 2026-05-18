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

Studio launches in the background, the script runs, and Studio stays up so subsequent `rodeo run` commands hit the same instance.

## Where to go next

See the full [CLI reference](/rodeo/cli/) for every subcommand and flag, or move on to [Client usage](/rodeo/getting-started/client-usage/) for programmatic control from Luau.
