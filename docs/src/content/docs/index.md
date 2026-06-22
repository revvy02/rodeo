---
title: rodeo
description: An automation tool for headless studio workflows that extends Roblox's Luau runtime with a complete standard library.
template: splash
hero:
  tagline: An automation tool for headless studio workflows that extends Roblox's Luau runtime with a complete standard library.
  actions:
    - text: Get started
      link: /rodeo/getting-started/installation/
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/revvy02/rodeo
      icon: external
---

:::danger
**Don't use rodeo unless you know what you're doing.** It deliberately circumvents Roblox Studio's sandbox to give your scripts host system access: spawning processes, reading and writing files, running shell commands, etc. A malicious or buggy script becomes a full machine compromise vector. Only run scripts you wrote or fully trust.

The plan is to replace the way the runtime APIs are exposed with a more secure model once the APIs are more finalized.
:::

## What rodeo is

`rodeo`, in contrast to Lune, extends Roblox Studio's own Luau runtime with a canonical standard library, so the code is written and executed inside the actual Studio VMs. Lune runs Luau as a separate runtime and provides APIs to interface with Roblox files from the outside.

The CLI is a workflow tool built around that runtime. It launches Studio, lets you orchestrate Studio and its modes, and runs scripts in different VMs with full host system access as a typical language runtime, giving you headless-like Studio workflows.

## Where to go next

- [Installation](/rodeo/getting-started/installation/)
- [CLI usage](/rodeo/getting-started/cli-usage/)
- [Runtime usage](/rodeo/getting-started/runtime-usage/)
- [CLI reference](/rodeo/cli/)
- [@rodeo runtime](/rodeo/runtime/)
