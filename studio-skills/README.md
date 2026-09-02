# studio-skills

A skill-creation workspace: generate the **Roblox Studio Assistant's built-in skills**
from the shipped `Assistant.rbxm`, then hand-modify them for use elsewhere.

- `raw/`     — generated, pristine extraction (don't edit)
- `curated/` — the hand-modified versions (what you actually ship)

The skills ship as `StringValue`s inside the Assistant plugin, zstd-compressed in the
rbxm — **not** fetched from any endpoint. The MCP `skill` tool only surfaces a
server-allowlisted subset (`rbx-debug`, `rbx-docs-search`, `rbx-scene-analysis`);
`extract.luau` dumps **all** of them.

## Workflow

1. **Generate** the pristine reference:
   ```bash
   lune run extract.luau          # Assistant.rbxm -> raw/   (all 16, verbatim)
   ```
   Needs Lune 0.10.5 or newer: older Lune's rbxm reader rejects the `Tags` property
   as current Studio serializes it (`mise install` on this repo gets the latest).
2. **Curate** — copy a skill into `curated/` and hand-edit it:
   ```bash
   cp -r raw/rbx-debug curated/rbx-debug    # then edit curated/rbx-debug/SKILL.md
   ```
   When editing:
   - drop `SKILL-combined.md` (just `SKILL.md` + commands/specs concatenated),
   - keep the frontmatter (`name` / `description`),
   - **remove/correct anything that assumes the in-Studio Assistant's context** — the
     base skills assume the Assistant (already elevated, privileged debugger channel),
     so claims like "plugin-level security, usable by plugins" mislead when driving via
     rodeo / the Studio MCP,
   - **inline the conversions** — map the Assistant's tool names onto rodeo targets /
     `mcp__Roblox_Studio__*`, and fold in anything verified by testing.
3. **Deploy** the curated skill where an agent will load it:
   ```bash
   cp -r curated/rbx-debug ../../../.claude/skills/rbx-debug   # e.g. the game repo
   ```

`raw/` stays pristine so after a Studio update you can re-extract, `diff raw/<skill>`
against `curated/<skill>`, and merge real changes by hand — without losing your edits.

## The 16 skills

| Skill | What it teaches | Engine API |
|-------|-----------------|------------|
| `rbx-debug` | breakpoints, `OnStopped`, thread/stack/variable inspection | `ScriptDebuggerService` |
| `scene-analysis` | triangles/draw calls, VM memory, unparented/leak tracing | `SceneAnalysisService` |
| `virtual-input` | click/type/key/scroll/camera on a live game | `VirtualInputManager` |
| `device-simulator` | test UI across device form factors | `StudioDeviceSimulatorService` |
| `docs-search` | look up create.roblox.com API docs | `http_get` |
| `open-cloud-usage` | Open Cloud auth + endpoint discovery | Open Cloud |
| `convert-to-streaming` | convert a place to streaming, fix anti-patterns | streaming |
| `luau-heap-profiling` | heap snapshots, allocation diffs, leak hunting | `HeapProfilerService` |
| `perf-profiling` | MicroProfiler CPU/GPU frame analysis via the LibMP Luau module | MicroProfiler / LibMP |
| `perf-profiling-ref` | reference variant of `perf-profiling` (same description, different body) | MicroProfiler / LibMP |
| `unit-test` | write, run, debug Luau unit tests for ModuleScripts | test runner |
| `unit-test-testservice` | `unit-test` variant that runs tests through TestService | `TestService` |
| `instrument-analytics` | audit and add Economy / Funnel / Custom events | `AnalyticsService` |
| `configs-experimentation` | live-tunable values and experiments instead of constants or DataStores | `ConfigService` |
| `process-receipt-misuse` | audit Developer Product receipt handling for ProcessReceipt misuse | `MarketplaceService` |
| `create-skill` | author or modify a custom Assistant skill | none |

`raw/` and `curated/` content is **Roblox's**, extracted from the local install.
`extract.luau` is original. The six curated skills are `rbx-debug`, `scene-analysis`, `virtual-input`, `device-simulator`, `docs-search`, and
`open-cloud-usage`; the other ten are extracted to `raw/` only — not yet curated.

## STUDIO_MCP_TOOLS.md

Reference for the live `mcp__Roblox_Studio__*` tool surface (params + what each does),
generated from the StudioMCP proxy's `tools-cache.json`.
