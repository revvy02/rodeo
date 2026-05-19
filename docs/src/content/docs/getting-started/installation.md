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

## Generate type definitions

```bash
rodeo setup
```

Writes `@rodeo` typedefs to `~/.rodeo/typedefs/<version>/` and registers them in `.rodeo/.luaurc` so your editor can type-check `require("@rodeo/fs")` etc.
