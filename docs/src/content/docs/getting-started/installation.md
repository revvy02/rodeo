---
title: Installation
---

## Install the rodeo CLI

```bash
mise use ubi:revvy02/rodeo
# or
rokit add revvy02/rodeo
```

Verify:

```bash
rodeo --version
```

## Studio plugin

There is no separate install step. The plugin is embedded in the CLI and written to Studio's local plugins folder as `rodeo.rbxm` whenever a serve starts:

```bash
rodeo serve
# or, which starts a serve if none is running on the port
rodeo run --place
```

The file is rewritten only when it differs from the running CLI's embedded plugin, so upgrading rodeo updates the plugin on the next serve start. Studio reloads a local plugin when its file changes, including in Studios that are already open.

Launched Studios connect to the serve that launched them. A Studio you open manually connects to the serve on the default port.

## Generate type definitions

```bash
rodeo setup
```

Writes `@rodeo` typedefs to `~/.rodeo/typedefs/<version>/` and registers them in `.rodeo/.luaurc` so your editor can type-check `require("@rodeo/fs")` etc.
