---
title: Remote usage
---

:::caution
Distributed usage is implemented but not fully tested.
:::

`rodeo serve` can be split into a **master** (orchestrator) and one or more **studio backends** (each fronting the Studio plugin on its host machine). The client connects to the master; the master routes RPCs to whichever backend owns the target Studio.

```
                              ┌──────────────────────────┐
   ┌─────────────┐   gRPC     │  Studio backend (host A) │ ─── Studio
   │             │ ─────────→ │  rodeo serve --studio    │
   │   Master    │            └──────────────────────────┘
   │  (any host) │
   │             │            ┌──────────────────────────┐
   │             │ ─────────→ │  Studio backend (host B) │ ─── Studio
   └─────────────┘   gRPC     │  rodeo serve --studio    │
         ↑                    └──────────────────────────┘
         │
       client (RodeoClient / rodeo CLI)
```

This is the same machinery `rodeo serve` runs internally — without flags, `serve` spawns a master and a single studio backend in the same process tree. The flags below break them apart so you can run them on different hosts.

## Run the master

On the central host:

```bash
rodeo serve --master --port 44872
```

This boots the master alone — no studio backend, no Studio launch. It listens on `44872` and waits for backends and clients to connect.

## Run a studio backend

On each host that should expose a Studio:

```bash
rodeo serve --studio \
    --master-host central.example.com \
    --master-port 44872 \
    --port 44873
```

Flags:
- `--master-host` — host running `rodeo serve --master` (default: `localhost`)
- `--master-port` — that master's port
- `--port` — local port the studio backend uses for its plugin WebSocket (any free port; the master tracks the backend by id, not port)

When the backend starts it registers itself with the master. Once Studio is open on the backend's host, the plugin auto-connects to `localhost:<port>` and the backend uplifts the resulting VMs to the master.

## Connect a client

A client only ever talks to the master. From any host that can reach it:

```luau
local rodeo = require("@pkg/rodeo")

local client = rodeo.connect({ host = "central.example.com", port = 44872 })
local backends = client.listBackends("studio")
print(backends)  -- backends from every host that registered
```

To target a specific backend's Studio:

```luau
local backend = client.getStudio("host-a-studio")
local studio = backend.open({ background = true })
```

`getLocalStudio()` resolves the Studio on the **master's** host. For everything else, pass the backend's id or name to `getStudio`.

## Caveat: localhost binding

Both `--master` and `--studio` currently bind to `127.0.0.1`. For true cross-machine setups today, you need a tunnel:

```bash
# Forward master's port from host A to host B so the studio backend on B
# can dial central.example.com:44872 as `localhost:44872`.
ssh -L 44872:localhost:44872 central.example.com
```

`cloudflared` and `ngrok` work similarly. Once the binding accepts non-localhost interfaces, this section can go away.

## Where to go next

- **[CLI reference](/rodeo/cli/)** — the full `serve` flag set
- **[Client usage](/rodeo/getting-started/client-usage/)** — driving Studios via the Luau client
