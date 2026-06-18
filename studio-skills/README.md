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
   lune run extract.luau          # Assistant.rbxm -> raw/   (all 7, verbatim)
   ```
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

## The 7 skills

| Skill | What it teaches | Engine API |
|-------|-----------------|------------|
| `rbx-debug` | breakpoints, `OnStopped`, thread/stack/variable inspection | `ScriptDebuggerService` |
| `scene-analysis` | triangles/draw calls, VM memory, unparented/leak tracing | `SceneAnalysisService` |
| `virtual-input` | click/type/key/scroll/camera on a live game | `VirtualInputManager` |
| `device-simulator` | test UI across device form factors | `StudioDeviceSimulatorService` |
| `docs-search` | look up create.roblox.com API docs | `http_get` |
| `open-cloud-usage` | Open Cloud auth + endpoint discovery | Open Cloud |
| `convert-to-streaming` | convert a place to streaming, fix anti-patterns | streaming |

`raw/` and `curated/` content is **Roblox's**, extracted from the local install.
`extract.luau` is original. (`convert-to-streaming` is extracted to `raw/` only — not yet curated.)

## STUDIO_MCP_TOOLS.md

Reference for the live `mcp__Roblox_Studio__*` tool surface (params + what each does),
generated from the StudioMCP proxy's `tools-cache.json`.
