<p align="center">
  <img src="assets/plugin/logo.png" width="200" />
</p>

# rodeo

[![Latest release](https://img.shields.io/github/v/release/revvy02/rodeo?include_prereleases&label=latest)](https://github.com/revvy02/rodeo/releases)
[![Latest stable](https://img.shields.io/github/v/release/revvy02/rodeo?label=stable)](https://github.com/revvy02/rodeo/releases)

`rodeo` is an automation tool for Roblox Studio. It lets you execute code in any Studio environment and control Studio from your terminal, while providing the complete studio luau runtime.

> **Status:** macOS and Windows are fully supported. Linux currently is not. Breaking changes to API may happen.

## Docs

**[revvy02.github.io/rodeo](https://revvy02.github.io/rodeo/)** — full reference site with search.

- [CLI reference](https://revvy02.github.io/rodeo/cli/) — every subcommand and flag (auto-generated from source).
- [@rodeo runtime](https://revvy02.github.io/rodeo/runtime/) — the runtime library scripts get inside Studio (fs, io, stream, process, roblox).

## Companion tools

- **[rbx-microprofiler](https://github.com/revvy02/rbx-microprofiler)** — view + diff Roblox microprofiler dumps captured via `rodeo run --profile`.
