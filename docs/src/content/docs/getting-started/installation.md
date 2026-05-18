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

## Install the Studio plugin

```bash
rodeo plugin
```

This builds and installs the companion Roblox Studio plugin into your local plugins folder. You only need to run it once per machine — and again when you upgrade rodeo.

The plugin auto-connects to a running rodeo server at `localhost:44872`.

## Optional: generate type definitions

```bash
rodeo setup
```

Writes `@rodeo` typedefs to `~/.rodeo/typedefs/<version>/` and registers them in `.rodeo/.luaurc` so your editor can type-check `require("@rodeo/fs")` etc.
