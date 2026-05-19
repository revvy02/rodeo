---
title: rodeo
description: An automation tool for headless studio workflows that extends Roblox's Luau runtime with a complete standard library.
template: splash
hero:
  tagline: An automation tool for headless studio workflows that extends Roblox's Luau runtime with a complete standard library.
  image:
    file: ../../assets/rodeo.jpeg
    alt: rodeo
  actions:
    - text: Get started
      link: /rodeo/getting-started/installation/
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/revvy02/rodeo
      icon: external
---

## What rodeo is

`rodeo`, in contrast to Lune, extends Roblox Studio's own Luau runtime with a canonical standard library, so the code is written and executed inside the actual Studio VMs. Lune runs Luau as a separate runtime and provides APIs to interface with Roblox files from the outside.

The CLI is a workflow tool built around that runtime. It launches Studio, drives plugin and play-test contexts, and runs scripts in them, giving you headless Studio automation.

## Where to go next

- [Installation](/rodeo/getting-started/installation/)
- [CLI usage](/rodeo/getting-started/cli-usage/)
- [Client usage](/rodeo/getting-started/client-usage/)
- [Runtime usage](/rodeo/getting-started/runtime-usage/)
- [Remote usage](/rodeo/getting-started/remote-usage/)
- [CLI reference](/rodeo/cli/)
- [Luau API](/rodeo/api/)
- [@rodeo runtime](/rodeo/runtime/)
