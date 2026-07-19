# Studio layout / plist mechanism (findings)

Reference for `layout.rs` (the `--show-widgets` UI strip). Everything here was
verified empirically against **Roblox Studio 0.730** on macOS by capturing the
plist, diffing manual layouts, and launching real studios. Re-verify against the
current Studio version before trusting a specific byte/key — this is Studio
internals and Roblox changes it.

## The plist

- Path: `~/Library/Preferences/com.roblox.RobloxStudio.plist` (binary `bplist`;
  `plist::Value` round-trips both binary and XML — preserve `is_binary`).
- Studio **writes its layout to the plist on close.** Reading the plist while a
  studio is running, or after a non-graceful exit, is unreliable — the studio's
  own writes confound it. Capture clean state only after a **graceful** close.

## Dock panels — `LayoutSettings.Docking.3.{edit_,play_,pserv_}`

Each key is `Data` holding a UTF-8 XML `<DockPanelLayouts>` document:

- **Panel definitions** have a `Type` attr. Dock widgets are
  `Type="Qtitan::DockWidgetPanel"` (Explorer/Properties/Output/plugins) or
  `Qtitan::DockDocumentPanel` (the script-editor tabset). Structural containers
  have numeric `Type` (`1`/`2`/…) named `Layout0` / `FixedSplitLayout*`.
- **Reference stubs** are `<Panel ID="…"/>` with **no** `Type` attr, nested in a
  `<Panels Count="N">` container. A panel is **visible** iff it has a reference
  stub in a container.
- **How Studio represents a hidden panel:** it removes the panel's reference
  stub (keeps the definition). Verified by capturing a manual "only Output"
  layout — only `outputWidgetPanel` + `ideDocDocumentPanel` stubs remained; every
  other widget's stub was gone. **Our transform matches this**: strip the
  reference stubs of hidden panels, keep definitions (removing a definition
  invalidates the layout and Studio regenerates defaults), strip `Active="True"`
  from hidden panels.
- `ideDocDocumentPanel` (script editor) is effectively **always kept** by
  Studio, even in "only Output". Our `--show-widgets output` removes it; that's
  fine (panels still hide), but note the divergence from Studio's own minimal.

### Verified panel IDs (aliases in `resolve_alias`)

| Alias | Panel ID |
|---|---|
| output | `outputWidgetPanel` |
| properties | `propertiesWidgetPanel` |
| explorer | `rplg_sabuiltin_ExplorerPlugin.rbxm_ExplorerPlugin` |
| editor | `ideDocDocumentPanel` |
| toolbox | `edit_builtin_Toolbox.rbxm_Toolbox` |
| assistant | `rplg_sabuiltin_Assistant.rbxm_Assistant` |

Naming patterns: built-in singletons (`outputWidgetPanel`), Studio built-in
plugins (`rplg_sabuiltin_<Name>.rbxm_<Widget>`), user plugins
(`edit_user_<file>.rbxm_<widgetId>`, **mode-prefixed** `edit_`/`play_`), cloud
plugins (`edit_cloud_<id>_<name>`). rodeo's own widget is
`edit_user_rodeo.rbxm_Rodeo-<port>`.

A **custom plugin widget's** live visibility is the plugin's own
`DockWidgetPluginGui.Enabled`, independent of the plist. The plist governs
built-in panels + persisted widget state.

## Ribbon — NOT controllable via plist on 0.730

- `rbxRibbonMinimized` (bool) is **dead**: Studio ignores it at launch and does
  not update it. It read `True` in both a minimized capture *and* a manually
  expanded one. **Do not rely on it; writing it is ineffective.**
- The real ribbon state is sticky in `LayoutSettings.window_state_beta_ribbon`
  (the `QMainWindow::saveState` blob). Diffing minimized vs expanded, the **only**
  difference (excluding session noise: `rbxRecentFiles*`, `RobloxAutocompleteWeights`,
  `ApplicationLocationOnCrash*`, `RPCServers*`) is a **4-byte BE value at offset
  131–134**: `0x000003b7` (951, minimized) vs `0x0000037c` (892, expanded).
- That value is a **content-area height** (~59px delta = ribbon height), i.e. a
  *consequence* of the ribbon state, **not a boolean flag**. There is no named
  anchor for the ribbon in the blob (only `GradientEditor`, `SplineEditor`,
  `commandToolBar` strings exist). Studio derives geometry *from* the ribbon
  state, so writing the height likely won't flip the state.
- **Conclusion:** the ribbon inherits its sticky persisted state; rodeo cannot
  toggle it cleanly/portably. Set the ribbon once manually and it persists.

## Command bar (Luau command bar) — works via named anchor

- Stored in the `window_state` blob as a Qt toolbar named **`commandToolBar`**
  (UTF-16-BE). Layout: `<4-byte BE length> <UTF-16BE name> <1-byte visibility> …`.
  The visibility byte immediately after the name is `0x01` (visible) / `0x00`
  (hidden). `hide_command_toolbar` finds the name and clears that byte.
- **Beta/non-beta split:** the blob exists per ribbon UI —
  `LayoutSettings.window_state_ribbon` (classic) and
  `LayoutSettings.window_state_beta_ribbon` (beta, gated by
  `IsEnrolledInRibbonBeta`). Only one is live at a time, so **patch both**
  (`WINDOW_STATE_KEYS`). (Aside: geometry keys use the *non-beta* naming
  `window_geometry_ribbon` — the naming is asymmetric.)

## filepatch restore semantics

- On **graceful** exit (run completes → serve tears down → studio handle drops),
  filepatch restores the plist correctly. Verified: a plain run leaves the config
  byte-identical (`edit_` layout hash MATCH); a `--show-widgets` run restores the
  baseline exactly. **This is the normal path and it works.**
- On **hard kill** (`SIGKILL` the studio, or killing the serve without graceful
  teardown), the restore does **not** run and the plist is left patched. A stale
  lock `com.roblox.RobloxStudio.plist.lock.<uuid>` is left behind; the next run
  treats it as the "original" (`no_original`), which self-heals but can propagate
  a degraded baseline. If diagnosing weird layout state, check for stale locks.

## Gotchas that wasted time (don't repeat)

- **Concurrent rodeo instances corrupt everything.** A second instance
  patching/launching in parallel degrades the plist and causes launch-correlation
  races (studio connects with the wrong session → CLI errors "stream ended
  without ready event" even though the run actually executed). If tests fail
  weirdly, confirm no other rodeo/Studio processes: `pgrep -x RobloxStudio`,
  `pgrep -f "rodeo __"`.
- **`--detach` restores the plist early**, racing the studio's layout read →
  the studio can revert to the unpatched layout. For visual verification, use a
  **blocking, non-detached** run (`task.wait(N)`) so the patch stays applied while
  the studio is up.
- To capture a clean layout for diffing: launch **Studio directly** (not via
  rodeo — no patching, no plugin), have a human arrange + close it, then read the
  plist. That's how the panel-hide representation and the ribbon byte were found.
