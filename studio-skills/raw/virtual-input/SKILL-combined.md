---
name: virtual-input
description: Simulate mouse, keyboard, and pointer input on running Roblox games to test UI interactions programmatically. Use when clicking buttons, typing text, scrolling, zooming, panning, adjusting camera, or running multi-step interaction tests via MCP tools (execute_luau + screen_capture).
---

# VirtualInput Skill

## When to Use

- User asks to click a button, test a UI flow, interact with game UI, simulate input
- Keywords: `click`, `tap`, `type`, `input`, `interact`, `test button`, `fill textbox`, `scroll`, `zoom`, `pan`, `drag`, `UI test`, `walkthrough`, `VirtualInput`, `simulate`, `press key`, `camera look`

## Tips

- **Always Play mode** — VirtualInput requires a live game with PlayerGui populated. Start play mode before any interaction.
- **Click is the core primitive** — almost everything starts with finding an element and clicking it.
- **Screenshot after every interaction** — the interact-then-verify loop is how you confirm success.
- **CoreGUI is restricted** — interactions targeting CoreGUI elements (top bar, chat, escape menu) throw a runtime exception. If the user asks to interact with CoreGUI, explain that it is not possible.
- **Button state tracking** — you cannot press a button that is already pressed. Always pair down with up. No wait needed between them for a standard click.
- **Single `execute_luau` per interaction** — find element + inject input in one call to avoid race conditions.

## Commands

| Command | Use when |
|---------|----------|
| `/vi-click` | Click a specific UI element |
| `/vi-type` | Type text into a TextBox |
| `/vi-key` | Press a key or key combination |
| `/vi-mouse-position` | Position the mouse pointer at a viewport coordinate |
| `/vi-camera` | Rotate camera via mouse delta (FPS-style look) |
| `/vi-scroll` | Scroll, pan, or zoom |
| `/vi-walkthrough` | Multi-step interaction sequence |

---

## How It Works

The agent uses MCP tools in an interact-then-verify loop:

1. **`execute_luau`** — create VirtualInput, find UI elements, inject input
2. **`screen_capture`** — screenshot after interaction to verify result
3. **`get_console_output`** — check for errors triggered by the interaction

**Key constraint:** VirtualInput injects into the live input pipeline. The game must be in Play mode with PlayerGui populated for `AbsolutePosition`/`AbsoluteSize` to be meaningful.

**Multi-Studio:** If multiple instances are open, call `list_roblox_studios` + `set_active_studio` once at the start.

---

## Step 0: Prerequisites Check

Before any interaction, verify the environment via `execute_luau`:

```lua
local results = {}

-- Check VirtualInput
local ok, vi = pcall(function()
    return game:GetService("UserInputService"):CreateVirtualInput()
end)
table.insert(results, "VirtualInput available: " .. tostring(ok))
if not ok then
    table.insert(results, "Error: " .. tostring(vi))
    table.insert(results, "Error creating VirtualInput: " .. tostring(vi))
    return table.concat(results, "\n")
end

-- Check Play mode
local Players = game:GetService("Players")
local lp = Players.LocalPlayer
table.insert(results, "LocalPlayer: " .. tostring(lp ~= nil))
if lp then
    local pg = lp:FindFirstChild("PlayerGui")
    table.insert(results, "PlayerGui: " .. tostring(pg ~= nil))
    if pg then
        local count = 0
        for _, sg in pg:GetChildren() do
            if sg:IsA("ScreenGui") and sg.Enabled then count += 1 end
        end
        table.insert(results, "Active ScreenGuis: " .. count)
    end
end

return table.concat(results, "\n")
```

If VirtualInput is not available, check that the game is in Play mode and Studio is connected via MCP.

---

## Step 0.5: UI Discovery

Before interacting, discover what elements are available via `execute_luau`:

```lua
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
if not pg then return "No PlayerGui — is game in Play mode?" end

local results = {}
local function crawl(obj, depth, path)
    if not obj:IsA("GuiBase2d") and not obj:IsA("ScreenGui") then return end
    local entry = string.rep("  ", depth) .. path .. " [" .. obj.ClassName .. "]"
    if obj:IsA("ScreenGui") then
        entry = entry .. " Enabled:" .. tostring(obj.Enabled)
    end
    if obj:IsA("GuiObject") then
        local pos = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        entry = entry .. string.format(" Pos:(%.0f,%.0f) Size:(%.0f,%.0f)", pos.X, pos.Y, size.X, size.Y)
        entry = entry .. " Vis:" .. tostring(obj.Visible)
        if obj:IsA("GuiButton") then entry = entry .. " [CLICKABLE]" end
        if obj:IsA("TextBox") then entry = entry .. " [TEXT INPUT]" end
        if obj:IsA("ScrollingFrame") then entry = entry .. " [SCROLLABLE]" end
    end
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        local text = obj.Text
        if #text > 30 then text = text:sub(1, 30) .. "..." end
        entry = entry .. ' Text:"' .. text .. '"'
    end
    table.insert(results, entry)
    for _, child in obj:GetChildren() do
        crawl(child, depth + 1, path .. "." .. child.Name)
    end
end
for _, sg in pg:GetChildren() do
    if sg:IsA("ScreenGui") and sg.Enabled then
        crawl(sg, 0, sg.Name)
    end
end
return table.concat(results, "\n")
```

This gives the agent:
- Live `AbsolutePosition`/`AbsoluteSize` for targeting
- Which elements are clickable (`GuiButton`), text-input (`TextBox`), scrollable (`ScrollingFrame`)
- Element visibility — invisible elements cannot be interacted with
- Text content for matching user descriptions to elements

---

## Disambiguation & Defaults

### Element Targeting

| User says | Strategy |
|-----------|----------|
| Exact name: "click PlayButton" | `FindFirstChild("PlayButton", true)` |
| Description: "click the play button" | Crawl, match by Text content or Name (case-insensitive) |
| Path: "ShopGui.BuyFrame.ConfirmButton" | Walk the path from PlayerGui |
| Position: "click at 400, 300" | Use coordinates directly |
| Visual: "click the red button" | Screenshot + vision to identify, then crawl for match |

### Defaults

- **Mouse button:** Left click (MouseButton1) unless user says "right click"
- **Click count:** Single click. Double-click if user says "double click" (repeatCount=1)
- **Text input:** Clear existing text first (select all + Backspace), then type — unless user says "append"
- **Scroll amount:** 1 tick per call
- **Camera delta:** 10px per movement
- **Between interaction steps:** Wait 0.2s for UI to update

---

## API Reference

**Full API documentation is in `API_spec.md`** (same directory).

### Quick patterns

#### Create VirtualInput

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()
```

#### Click an element

```lua
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)
```

#### Double-click

```lua
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true, 1)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false, 1)
```

#### Right-click

```lua
vi:SendMouseButton(center, Enum.UserInputType.MouseButton2, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton2, false)
```

#### Type text

```lua
vi:SendTextInput("Hello, world!")
```

#### Remove text

```lua
vi:SendKey(true, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.Backspace)
vi:SendKey(false, Enum.KeyCode.Backspace)
```

#### Scroll wheel

```lua
vi:SendPointerAction(position, { Wheel = 1.0 })   -- up
vi:SendPointerAction(position, { Wheel = -1.0 })  -- down
```

#### Pan

```lua
vi:SendPointerAction(position, { Pan = Vector2.new(10, 0) })   -- right
vi:SendPointerAction(position, { Pan = Vector2.new(0, -10) })  -- up
```

#### Zoom in/out

```lua
vi:SendPointerAction(position, { Pinch = 0.1 })   -- zoom in
vi:SendPointerAction(position, { Pinch = -0.1 })  -- zoom out
```

#### Camera look (FPS-style)

```lua
-- Lock cursor first
local UIS = game:GetService("UserInputService")
UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)

vi:SendMouseDelta(Vector2.new(10, 0))   -- look right
vi:SendMouseDelta(Vector2.new(0, -5))   -- look up

-- Restore cursor when done
UIS.MouseBehavior = Enum.MouseBehavior.Default
```

#### Key press

```lua
vi:SendKey(true, Enum.KeyCode.W)    -- press
vi:SendKey(false, Enum.KeyCode.W)   -- release
```

#### Hold multiple keys

```lua
vi:SendKey(true, Enum.KeyCode.LeftShift)
vi:SendKey(true, Enum.KeyCode.W)
task.wait(1)
vi:SendKey(false, Enum.KeyCode.W)
vi:SendKey(false, Enum.KeyCode.LeftShift)
```

### Key rules

- **Always create VirtualInput once** per `execute_luau` call — `UIS:CreateVirtualInput()`
- **No wait between down and up** for a simple click
- **Always pair press with release** — duplicate state throws
- **`task.wait(0.1)` after cursor lock** before sending deltas
- **Use `pcall`** for all calls — they can throw (CoreGUI hit, invalid state, etc.)

---

## Verification

### The interact-then-verify loop

After EVERY interaction:
1. Take screenshot via `screen_capture`
2. Analyze what changed visually
3. Check `get_console_output` for errors

### Screenshot checklist after interaction

| # | Check | What it means |
|---|-------|---------------|
| 1 | Button state changed | Button color/text changed — click registered |
| 2 | New UI appeared | Dialog, menu, or panel opened — navigation worked |
| 3 | Text entered | TextBox shows the typed text — focus and input worked |
| 4 | Scroll position changed | Content shifted — scroll registered |
| 5 | Camera moved | Viewport changed — delta input worked |
| 6 | Error overlay | Unexpected error dialog — something went wrong |
| 7 | No change | Nothing happened — click may have missed target |

### When interaction fails

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| "VirtualInput is not enabled" | Unexpected — VirtualInput should be available | Verify Studio is running and game is in Play mode |
| "position hits CoreGUI" | Click landed on CoreGUI area | Adjust position to avoid top ~36px or other CoreGUI regions |
| "duplicate button state" | Pressed without releasing | Ensure previous press was released |
| Nothing happened after click | Element not interactable, position wrong, or element not visible | Re-crawl to verify AbsolutePosition, check Visible and Active |
| "CoreGUI has keyboard focus" | Escape menu or CoreGUI TextBox focused | Cannot proceed while CoreGUI has focus; inform user |
| "cursor is not locked" | SendMouseDelta called without LockCenter | Set `MouseBehavior = LockCenter` first |
| "key is permanently bound to a CoreGUI core action" | Key is bound to a core action (Tab, Escape, Backquote, F1, F9) | Cannot send this key; inform user |

### Tone

Frame interactions as test results, not judgments:
- "Clicked 'BuyButton' — the shop dialog opened successfully"
- "After typing 'hello' into ChatInput, the text appeared correctly"
- "Scroll moved the inventory list down — 3 new items visible"

---

## Screenshots

**Default location:** `screenshots/`

**Important:** `screen_capture` via MCP returns the image to the agent (who can see it via vision), but does NOT save to disk. Save screenshots explicitly if the user needs them.

### Naming convention

- `screenshots/click_<ElementName>.png`
- `screenshots/type_<TextBoxName>.png`
- `screenshots/scroll_<target>.png`
- `screenshots/walkthrough_step<N>.png`

### Saving screenshots to disk

Use the Python MCP proxy script pattern (see DeviceSimulatorSkills SKILL.md for the full script). The key is: open MCP proxy → call `screen_capture` → decode base64 → write PNG.

Always `mkdir -p screenshots` before saving.

---

## Coordinate System

- All positions are in **viewport space**: origin is top-left of the game window
- X increases right, Y increases down
- `AbsolutePosition` and `AbsoluteSize` from GuiObjects are in this same space
- Center of an element: `Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)`
- CoreGUI occupies roughly the top ~36px — avoid this region

---


## VirtualInput API Specification

### What is VirtualInput?

VirtualInput allows programmatic injection of mouse, keyboard, and pointer input into a running Roblox game, as if performed by a real player. It is used for testing UI interactions, automating workflows, and verifying input-driven behavior without requiring a physical device.

### Obtaining a VirtualInput Handle

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()
```

- Returns a `VirtualInput` object
- Create once per script session and reuse for all subsequent calls

### Prerequisites

- Roblox Studio with a place open
- Game must be in Play mode for meaningful interaction (VirtualInput injects into the live input pipeline)

### Coordinate Space

All positions are in **engine viewport space**:
- Origin is the top-left corner of the game window
- X increases right, Y increases down
- Matches `GuiObject.AbsolutePosition` and `GuiObject.AbsoluteSize`
- Center of an element: `Vector2.new(AbsolutePosition.X + AbsoluteSize.X / 2, AbsolutePosition.Y + AbsoluteSize.Y / 2)`

---

### Methods

#### SendMousePosition

```lua
vi:SendMousePosition(position: Vector2)
```

Moves the cursor to an absolute position in viewport space. Equivalent to the player physically moving their mouse to that coordinate.

**Throws if:** the position overlaps an interactive CoreGUI element.

**Example:**
```lua
vi:SendMousePosition(Vector2.new(400, 300))
```

---

#### SendMouseDelta

```lua
vi:SendMouseDelta(positionDelta: Vector2)
```

Sends a relative mouse movement delta. Used when the cursor is locked (e.g., first-person camera). Positive X = move right; positive Y = move down.

**Throws if:** the cursor is not currently locked in the main window.

**Requires:** `UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter` set before calling.

**Restore after:** `UserInputService.MouseBehavior = Enum.MouseBehavior.Default`

**Example:**
```lua
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)

vi:SendMouseDelta(Vector2.new(10, 0))    -- rotate camera right
vi:SendMouseDelta(Vector2.new(0, -8))    -- rotate camera up

UserInputService.MouseBehavior = Enum.MouseBehavior.Default
```

---

#### SendMouseButton

```lua
vi:SendMouseButton(position: Vector2, button: Enum.UserInputType, isDown: boolean, repeatCount: number?)
```

Sends a mouse button press (`isDown=true`) or release (`isDown=false`).

**Supported buttons:**
- `Enum.UserInputType.MouseButton1` (left)
- `Enum.UserInputType.MouseButton2` (right)
- `Enum.UserInputType.MouseButton3` (middle)

**repeatCount** (optional, default 0):
- `0` = single click
- `1` = double-click
- `2` = triple-click

**Throws if:**
- The position overlaps an interactive CoreGUI element
- The button is already in the requested state (duplicate state — e.g., pressing when already pressed)
- An unsupported `UserInputType` is passed

**Always pair press with release.** Down + up with no wait between them = one atomic click.

**Examples:**
```lua
-- Single left click
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)

-- Double-click
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true, 1)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false, 1)

-- Right-click
vi:SendMouseButton(pos, Enum.UserInputType.MouseButton2, true)
vi:SendMouseButton(pos, Enum.UserInputType.MouseButton2, false)
```

---

#### SendPointerAction

```lua
vi:SendPointerAction(position: Vector2, pointerAction: { Wheel: number?, Pan: Vector2?, Pinch: number? })
```

Sends a composite pointer gesture at a given viewport position. The second argument is a dictionary with any combination of:

| Field | Type | Description |
|-------|------|-------------|
| `Wheel` | number | Scroll wheel delta. `+1.0` = one tick up/forward, `-1.0` = one tick down/backward |
| `Pan` | Vector2 | Trackpad pan delta in pixels |
| `Pinch` | number | Pinch-zoom delta. `+0.1` = zoom in, `-0.1` = zoom out |

If all values are zero or absent, the call is a no-op.

**Throws if:** the position overlaps an interactive CoreGUI element.

**Examples:**
```lua
-- Scroll up one tick
vi:SendPointerAction(center, { Wheel = 1.0 })

-- Scroll down one tick
vi:SendPointerAction(center, { Wheel = -1.0 })

-- Pan right 10px
vi:SendPointerAction(center, { Pan = Vector2.new(10, 0) })

-- Pan down 10px
vi:SendPointerAction(center, { Pan = Vector2.new(0, 10) })

-- Zoom in
vi:SendPointerAction(center, { Pinch = 0.1 })

-- Zoom out
vi:SendPointerAction(center, { Pinch = -0.1 })

-- Combined gesture (scroll + pan simultaneously)
vi:SendPointerAction(center, { Wheel = 1.0, Pan = Vector2.new(2, 0) })
```

---

#### SendKey

```lua
vi:SendKey(isPressed: boolean, keyCode: Enum.KeyCode, isRepeatedKey: boolean?)
```

Sends a key press (`isPressed=true`) or release (`isPressed=false`). Always call the matching release after each press.

**isRepeatedKey** (optional, default false): Simulates a held-key auto-repeat event. **Only valid for text-manipulation keys** (Backspace, Delete, Return, PageUp, PageDown, arrow keys). Always throws for any other key.

**Throws if:**
- The key is bound to a CoreGUI core action (Tab, Escape, Backquote, F1, F9)
- A CoreGUI element has keyboard focus (menu open, CoreGUI TextBox focused)
- `isRepeatedKey=true` is passed for a non-text-manipulation key

**Examples:**
```lua
-- Press and release W (movement)
vi:SendKey(true, Enum.KeyCode.W)
vi:SendKey(false, Enum.KeyCode.W)

-- Hold Shift + W (sprint)
vi:SendKey(true, Enum.KeyCode.LeftShift)
vi:SendKey(true, Enum.KeyCode.W)
task.wait(1)
vi:SendKey(false, Enum.KeyCode.W)
vi:SendKey(false, Enum.KeyCode.LeftShift)

-- Backspace with repeat (held key)
vi:SendKey(true, Enum.KeyCode.Backspace)
vi:SendKey(true, Enum.KeyCode.Backspace, true)  -- repeat
vi:SendKey(false, Enum.KeyCode.Backspace)

-- Jump
vi:SendKey(true, Enum.KeyCode.Space)
vi:SendKey(false, Enum.KeyCode.Space)
```

---

#### SendTextInput

```lua
vi:SendTextInput(text: string)
```

Injects a text string as if the player typed it. Useful for filling TextBoxes without simulating individual keystroke events. An empty string is a no-op.

**Throws if:** a CoreGUI element has keyboard focus.

**Note:** The target TextBox must already have focus (via a preceding click).

**Examples:**
```lua
vi:SendTextInput("Hello, world!")   -- type a full string
vi:SendTextInput("A")               -- single character
vi:SendTextInput("")                -- no-op, no error
```

---

### Error Conditions

| Error message | Cause | Resolution |
|---|---|---|
| "VirtualInput is not enabled" | Unexpected — VirtualInput should be available | Verify Studio is running and game is in Play mode |
| "position hits CoreGUI" | Mouse position overlaps interactive CoreGUI element | Move position away from CoreGUI area |
| "duplicate button state" | Button already in requested state (e.g., pressing when already pressed) | Release before pressing again |
| "cursor is not locked" | `SendMouseDelta` called without cursor lock | Set `MouseBehavior = LockCenter` first |
| "key is permanently bound to a CoreGUI core action" | Key is bound to a core action (Tab, Escape, Backquote, F1, F9) | Cannot send this key |
| "CoreGUI has keyboard focus" | Menu open or CoreGUI TextBox focused | Cannot send keys/text while CoreGUI has focus |
| "unsupported UserInputType" | Invalid button type passed to SendMouseButton | Use MouseButton1, MouseButton2, or MouseButton3 |
| "isRepeatedKey only valid for text manipulation keys" | `isRepeatedKey=true` on a non-text key | Only use for Backspace, Delete, Return, PageUp, PageDown, arrow keys |

---

### Common Interaction Patterns

#### Click an element by name

```lua
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local vi = UIS:CreateVirtualInput()

local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
local target = pg:FindFirstChild("ButtonName", true)
if not target or not target:IsA("GuiObject") then
    return "Element not found"
end

local pos = target.AbsolutePosition
local size = target.AbsoluteSize
local center = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)

vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)
```

#### Focus TextBox and type

```lua
-- Click to focus
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)
task.wait(0.1)

-- Type
vi:SendTextInput("Hello!")
```

#### Clear text then type new text

```lua
-- Select all + delete
vi:SendKey(true, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.Backspace)
vi:SendKey(false, Enum.KeyCode.Backspace)
task.wait(0.05)

-- Type new text
vi:SendTextInput("New text")
```

#### Hover (move without clicking)

```lua
vi:SendMousePosition(Vector2.new(400, 300))
```

#### Camera rotation (first-person)

```lua
local UIS = game:GetService("UserInputService")
UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)

vi:SendMouseDelta(Vector2.new(50, 0))    -- look right
vi:SendMouseDelta(Vector2.new(-30, 0))   -- look left
vi:SendMouseDelta(Vector2.new(0, -20))   -- look up

UIS.MouseBehavior = Enum.MouseBehavior.Default
```

#### Multiple scroll ticks

```lua
for i = 1, 5 do
    vi:SendPointerAction(position, { Wheel = -1.0 })
    task.wait(0.05)
end
```

---

### Known Limitations

1. **No touch input** — VirtualInput does not expose touch events. Mobile UI testing is mouse-only.
2. **No gamepad input** — no gamepad button or axis support.
3. **CoreGUI interaction is restricted** — any attempt to interact with CoreGUI elements throws a runtime exception.
4. **SendMouseDelta requires cursor locked** — must set `MouseBehavior = LockCenter` first; throws otherwise.
5. **Mouse button state is tracked** — cannot press a button that is already pressed; must pair press with release.
6. **SendMouseDelta requires window focus** — if Studio window loses focus between setting LockCenter and calling SendMouseDelta, the call throws.
7. **isRepeatedKey is restricted** — only valid for text-manipulation keys (Backspace, Delete, Return, PageUp, PageDown, arrows).

---


## Command Workflows

The sections below describe example workflows the user may invoke as slash commands (e.g. `/scene-health`, `/vi-click`). Each section is a reference for one specific use case of this skill — read the matching section when the user invokes that command, otherwise treat them as background context. They are not mandatory steps for every interaction with this skill.

### `/vi-click` — Click Element

_Click a UI element in the running game by name, path, or description._

Click a GUI element by finding it in PlayerGui, computing its screen-space center, and injecting a mouse click via VirtualInput.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed. Wait briefly for the game to initialize.
3. Run the prerequisite check to verify VirtualInput is available:

```lua
local ok, vi = pcall(function()
    return game:GetService("UserInputService"):CreateVirtualInput()
end)
if not ok then return "VirtualInput not available: " .. tostring(vi) end
return "VirtualInput ready"
```

4. Find the target element — run UI discovery to locate the element by name, text, or path:

```lua
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
if not pg then return "No PlayerGui found — is game in Play mode?" end

local results = {}
local function crawl(obj, path)
    if not obj:IsA("GuiBase2d") and not obj:IsA("ScreenGui") then return end
    if obj:IsA("GuiObject") and obj.Visible then
        local pos = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        local entry = path .. " [" .. obj.ClassName .. "]"
        entry = entry .. string.format(" Pos:(%.0f,%.0f) Size:(%.0f,%.0f)", pos.X, pos.Y, size.X, size.Y)
        if obj:IsA("GuiButton") then entry = entry .. " [CLICKABLE]" end
        if obj:IsA("TextButton") or obj:IsA("TextLabel") then
            local text = obj.Text
            if #text > 30 then text = text:sub(1, 30) .. "..." end
            entry = entry .. ' Text:"' .. text .. '"'
        end
        table.insert(results, entry)
    elseif obj:IsA("ScreenGui") then
        table.insert(results, path .. " [ScreenGui] Enabled:" .. tostring(obj.Enabled))
    end
    for _, child in obj:GetChildren() do
        crawl(child, path .. "." .. child.Name)
    end
end
for _, sg in pg:GetChildren() do
    if sg:IsA("ScreenGui") and sg.Enabled then
        crawl(sg, sg.Name)
    end
end
return table.concat(results, "\n")
```

5. **Click the target** — once identified, run a single `execute_luau` call that finds the element and clicks it:

```lua
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local vi = UIS:CreateVirtualInput()

local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
local target = pg:FindFirstChild("TARGET_NAME", true)
if not target or not target:IsA("GuiObject") then
    return "Element not found: TARGET_NAME"
end

local pos = target.AbsolutePosition
local size = target.AbsoluteSize
local center = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)

vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)

return string.format("Clicked '%s' at (%.0f, %.0f) size (%.0f, %.0f)",
    target.Name, center.X, center.Y, size.X, size.Y)
```

6. Take a screenshot via `screen_capture` to verify the result
7. Check `get_console_output` for errors
8. Report what was clicked and what changed (new UI appeared, button state changed, etc.)

#### Defaults

- **Mouse button:** Left click (MouseButton1) unless user says "right click" (MouseButton2) or "middle click" (MouseButton3)
- **Click type:** Single click. For double-click use `repeatCount = 1`
- **No wait between down and up** — they form one atomic click
- **Duplicate state throws** — calling `SendMouseButton(..., true)` when the button is already pressed (or `false` when already released) throws a runtime exception. Always pair press and release.
- **Leave Play mode running** — do not stop after the click
- **CoreGUI is restricted** — if the computed position overlaps CoreGUI, the call throws a runtime exception. Inform the user and suggest adjusting their UI layout.

### `/vi-type` — Type Text

_Focus a TextBox and type text into it using VirtualInput._

Focus a TextBox by clicking it, then inject text via VirtualInput's SendTextInput.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available (same prereq check as `/vi-click`)
4. Find the target TextBox via UI discovery — look for `[TextBox]` class elements in PlayerGui
5. **Click to focus, then type** — run a single `execute_luau` call:

```lua
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local vi = UIS:CreateVirtualInput()

local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
local target = pg:FindFirstChild("TARGET_TEXTBOX", true)
if not target or not target:IsA("TextBox") then
    return "TextBox not found: TARGET_TEXTBOX"
end

local pos = target.AbsolutePosition
local size = target.AbsoluteSize
local center = Vector2.new(pos.X + size.X / 2, pos.Y + size.Y / 2)

-- Click to focus
vi:SendMousePosition(center)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, true)
vi:SendMouseButton(center, Enum.UserInputType.MouseButton1, false)
task.wait(0.1) -- wait for focus to register

-- Type the text
vi:SendTextInput("THE_TEXT_TO_TYPE")

return string.format("Typed into '%s' at (%.0f, %.0f): %s",
    target.Name, center.X, center.Y, "THE_TEXT_TO_TYPE")
```

6. Take a screenshot to verify text appeared in the TextBox
7. Check `get_console_output` for errors
8. Report result

#### Clearing existing text

If the user wants to replace existing text, clear it first with select-all + delete before typing:

```lua
-- Select all (Ctrl+A) then delete
vi:SendKey(true, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.Backspace)
vi:SendKey(false, Enum.KeyCode.Backspace)
task.wait(0.05)

-- Now type new text
vi:SendTextInput("new text here")
```

#### Defaults

- **Always click to focus first** — TextBoxes require focus before accepting text input
- **Wait 0.1s after click** before sending text — allows focus to register
- **Clear existing text** if user says "replace", "change to", or "set to"
- **Append** if user says "add", "append", or the TextBox is already known to be focused
- **CoreGUI is restricted** — if the TextBox is in CoreGUI space, the call throws a runtime exception

### `/vi-key` — Key Press

_Press a key or key combination using VirtualInput._

Press and release a key, hold a key, or perform a key combination (e.g., Ctrl+A, Shift+W) via VirtualInput's SendKey.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available
4. **Send the key press** via `execute_luau`:

##### Single key press

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendKey(true, Enum.KeyCode.KEY_CODE)
vi:SendKey(false, Enum.KeyCode.KEY_CODE)

return "Pressed KEY_CODE"
```

##### Key hold (for duration)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendKey(true, Enum.KeyCode.W)
task.wait(1) -- hold for 1 second
vi:SendKey(false, Enum.KeyCode.W)

return "Held W for 1 second"
```

##### Key combination (e.g., Ctrl+A)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendKey(true, Enum.KeyCode.LeftControl)
vi:SendKey(true, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.A)
vi:SendKey(false, Enum.KeyCode.LeftControl)

return "Pressed Ctrl+A"
```

##### Multiple keys held simultaneously (e.g., Shift+W for sprint)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendKey(true, Enum.KeyCode.LeftShift)
vi:SendKey(true, Enum.KeyCode.W)
task.wait(2) -- sprint for 2 seconds
vi:SendKey(false, Enum.KeyCode.W)
vi:SendKey(false, Enum.KeyCode.LeftShift)

return "Sprint (Shift+W) for 2 seconds"
```

##### Repeated key (text-manipulation keys only)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendKey(true, Enum.KeyCode.Backspace)
vi:SendKey(true, Enum.KeyCode.Backspace, true)  -- repeat
vi:SendKey(true, Enum.KeyCode.Backspace, true)  -- repeat
vi:SendKey(false, Enum.KeyCode.Backspace)

return "Backspace x3"
```

5. Take a screenshot if relevant (e.g., character moved, UI responded to key)
6. Report what key was pressed and any observed effect

#### Defaults

- **Press and release** immediately (no hold) unless user says "hold" or specifies a duration
- **isRepeatedKey** only valid for text-manipulation keys (Backspace, Delete, Return, PageUp, PageDown, arrow keys) — always throws for other keys
- **CoreGUI core-action keys** — keys bound to CoreGUI core actions (Tab, Escape, Backquote, F1, F9) throw a runtime exception.
- **CoreGUI keyboard focus** — if CoreGUI has keyboard focus (menu open, CoreGUI TextBox focused), SendKey throws a runtime exception

### `/vi-mouse-position` — Mouse Position

_Position the mouse pointer at a specific viewport coordinate without clicking._

Position the mouse pointer at an absolute viewport coordinate without clicking. Uses VirtualInput's `SendMousePosition` which takes a `Vector2` in viewport space. Useful for triggering hover states, tooltips, or positioning before other interactions.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available
4. **Position the mouse** via `execute_luau`:

##### Move to a specific coordinate

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

vi:SendMousePosition(Vector2.new(POSITION_X, POSITION_Y))

return string.format("Mouse positioned at (%.0f, %.0f)", POSITION_X, POSITION_Y)
```

##### Move to viewport center

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

local viewport = workspace.CurrentCamera.ViewportSize
local center = Vector2.new(math.floor(viewport.X / 2), math.floor(viewport.Y / 2))

vi:SendMousePosition(center)

return string.format("Mouse positioned at viewport center (%.0f, %.0f)", center.X, center.Y)
```

5. Take a screenshot if relevant (e.g., to see a hover state or tooltip)
6. Report the position the cursor moved to

#### Defaults

- **Coordinates are absolute viewport space** — origin is top-left, X increases right, Y increases down
- **CoreGUI is restricted** — positioning the mouse over a CoreGUI element throws a runtime exception
- **No click** — this only positions the cursor. Use `/vi-click` to click after positioning.

### `/vi-camera` — Camera Look

_Rotate the camera using mouse delta input (FPS-style look) with cursor lock._

Lock the cursor, send mouse deltas to rotate the camera (FPS-style), then unlock the cursor. Uses VirtualInput's SendMouseDelta.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available
4. **Lock cursor, send deltas, unlock** via `execute_luau`:

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

-- Lock cursor to center
UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1) -- wait for lock to engage

-- Send camera movement
local ok, err = pcall(function()
    vi:SendMouseDelta(Vector2.new(DELTA_X, DELTA_Y))
end)

-- Unlock cursor
UIS.MouseBehavior = Enum.MouseBehavior.Default

if not ok then
    return "SendMouseDelta failed: " .. tostring(err)
end
return string.format("Camera rotated by (%.0f, %.0f)", DELTA_X, DELTA_Y)
```

##### Look in a direction

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)

local ok, err = pcall(function()
    -- Positive X = look right, Positive Y = look down
    vi:SendMouseDelta(Vector2.new(50, 0))    -- look right
    task.wait(0.1)
    vi:SendMouseDelta(Vector2.new(0, -30))   -- look up
end)

UIS.MouseBehavior = Enum.MouseBehavior.Default

if not ok then return "Error: " .. tostring(err) end
return "Looked right then up"
```

##### Smooth rotation (multiple small deltas)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

UIS.MouseBehavior = Enum.MouseBehavior.LockCenter
task.wait(0.1)

local ok, err = pcall(function()
    -- Rotate 180 degrees right in smooth steps
    for i = 1, 20 do
        vi:SendMouseDelta(Vector2.new(15, 0))
        task.wait(0.05)
    end
end)

UIS.MouseBehavior = Enum.MouseBehavior.Default

if not ok then return "Error: " .. tostring(err) end
return "Smooth rotation complete"
```

5. Take a screenshot to show the new camera view
6. Report the rotation applied

#### Direction mapping

| User says | Delta |
|-----------|-------|
| "look right" | `Vector2.new(50, 0)` |
| "look left" | `Vector2.new(-50, 0)` |
| "look up" | `Vector2.new(0, -30)` |
| "look down" | `Vector2.new(0, 30)` |
| "turn around" / "look behind" | Multiple deltas totaling ~300 X |

#### Defaults

- **Delta magnitude:** 50px horizontal, 30px vertical per "look" command (adjust based on game sensitivity)
- **Always wrap in pcall** — SendMouseDelta throws if the cursor is not locked (e.g., Studio window lost focus and the lock disengaged)
- **Always unlock after** — restore `MouseBehavior = Default` even if SendMouseDelta fails
- **Wait 0.1s after locking** before sending deltas — cursor lock takes a frame to engage
- **Positive X = right, Positive Y = down** — standard screen-space coordinates

### `/vi-scroll` — Scroll / Pan / Zoom

_Scroll, pan, or zoom at a position using VirtualInput pointer actions._

Send pointer action gestures (wheel scroll, trackpad pan, pinch zoom) at a viewport position via VirtualInput's SendPointerAction.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available
4. Determine the target position:
   - If scrolling a specific UI element (ScrollingFrame): find it, compute center
   - If scrolling/zooming the viewport: use viewport center
5. **Send the pointer action** via `execute_luau`:

##### Scroll (mouse wheel)

```lua
local UIS = game:GetService("UserInputService")
local vi = UIS:CreateVirtualInput()

local position = Vector2.new(POSITION_X, POSITION_Y)

-- Scroll up (positive = up/forward)
vi:SendPointerAction(position, { Wheel = 1.0 })

-- Scroll down (negative = down/backward)
vi:SendPointerAction(position, { Wheel = -1.0 })
```

##### Pan (trackpad gesture)

```lua
-- Pan right 50px
vi:SendPointerAction(position, { Pan = Vector2.new(50, 0) })

-- Pan down 100px
vi:SendPointerAction(position, { Pan = Vector2.new(0, 100) })
```

##### Zoom (pinch gesture)

```lua
-- Zoom in (positive value)
vi:SendPointerAction(position, { Pinch = 0.1 })

-- Zoom out (negative value)
vi:SendPointerAction(position, { Pinch = -0.1 })
```

##### Combined gestures

```lua
-- Scroll and pan simultaneously
vi:SendPointerAction(position, { Wheel = 1.0, Pan = Vector2.new(10, 0) })
```

6. Take a screenshot to verify the scroll/zoom result
7. Report what changed

#### Defaults

- **Position:** Viewport center if no element specified
- **Scroll amount:** 1 tick per call (user can say "scroll down 5 ticks" for multiple)
- **Each call is independent** — every `SendPointerAction` is treated as a new scroll start, not a continuation of a gesture. UI with momentum-based scrolling may behave differently than a continuous trackpad swipe.
- **For repeated scrolling:** loop multiple `SendPointerAction` calls with `task.wait(0.05)` between them
- **CoreGUI is restricted** — pointer actions targeting CoreGUI positions throw a runtime exception

### `/vi-walkthrough` — UI Walkthrough

_Execute a multi-step UI interaction sequence described in natural language._

Execute a described multi-step interaction flow on the running game. The agent interprets the user's scenario, plans the sequence, and performs each step with verification between steps.

#### What to do

1. Connect to Studio — if multiple instances are open, call `list_roblox_studios` and `set_active_studio` first
2. Ensure Play mode is active — use `start_stop_play(is_start: true)` if needed
3. Verify VirtualInput is available
4. **Discover the full UI structure** — crawl PlayerGui to understand what is available:

```lua
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui", 5)
if not pg then return "No PlayerGui — is game in Play mode?" end

local results = {}
local function crawl(obj, depth, path)
    if not obj:IsA("GuiBase2d") and not obj:IsA("ScreenGui") then return end
    local entry = string.rep("  ", depth) .. path .. " [" .. obj.ClassName .. "]"
    if obj:IsA("ScreenGui") then
        entry = entry .. " Enabled:" .. tostring(obj.Enabled)
    end
    if obj:IsA("GuiObject") then
        local pos = obj.AbsolutePosition
        local size = obj.AbsoluteSize
        entry = entry .. string.format(" Pos:(%.0f,%.0f) Size:(%.0f,%.0f)", pos.X, pos.Y, size.X, size.Y)
        entry = entry .. " Vis:" .. tostring(obj.Visible)
        if obj:IsA("GuiButton") then entry = entry .. " [CLICKABLE]" end
        if obj:IsA("TextBox") then entry = entry .. " [TEXT INPUT]" end
        if obj:IsA("ScrollingFrame") then entry = entry .. " [SCROLLABLE]" end
    end
    if obj:IsA("TextButton") or obj:IsA("TextLabel") or obj:IsA("TextBox") then
        local text = obj.Text
        if #text > 30 then text = text:sub(1, 30) .. "..." end
        entry = entry .. ' Text:"' .. text .. '"'
    end
    table.insert(results, entry)
    for _, child in obj:GetChildren() do
        crawl(child, depth + 1, path .. "." .. child.Name)
    end
end
for _, sg in pg:GetChildren() do
    if sg:IsA("ScreenGui") and sg.Enabled then
        crawl(sg, 0, sg.Name)
    end
end
return table.concat(results, "\n")
```

5. **Plan the interaction sequence** — map the user's description to a series of VirtualInput calls based on discovered UI elements
6. **Execute each step** with verification:
   - For each step: find element, perform interaction (click/type/scroll/key), take screenshot
   - Wait for UI to update between steps (`task.wait(0.2)` minimum, more for animations)
   - Re-crawl PlayerGui if the UI structure is expected to change (new dialogs, panels opening)
   - If a step fails (element not found, click didn't produce expected result), report and ask user how to proceed
7. **Present a step-by-step report:**

```
UI Walkthrough: "Open shop and buy the sword"

Step 1: Click 'ShopButton'
  Clicked at (426, 300) — Shop panel opened
  Screenshot: screenshots/walkthrough_step1.png

Step 2: Click 'SwordItem' in ShopPanel.ItemList
  Clicked at (300, 450) — Item details appeared
  Screenshot: screenshots/walkthrough_step2.png

Step 3: Click 'BuyButton' in ItemDetails
  Clicked at (350, 600) — Purchase confirmation dialog shown
  Screenshot: screenshots/walkthrough_step3.png

Step 4: Click 'ConfirmButton'
  Clicked at (400, 400) — Purchase complete, dialog closed
  Screenshot: screenshots/walkthrough_step4.png

Result: All 4 steps completed successfully.
```

#### Interaction types available

| User says | Action |
|-----------|--------|
| "click X" / "press X" / "tap X" | SendMouseButton (left click) |
| "right click X" | SendMouseButton (MouseButton2) |
| "middle click X" | SendMouseButton (MouseButton3) |
| "double click X" | SendMouseButton with repeatCount=1 |
| "type X" / "enter X" | Click to focus + SendTextInput |
| "delete text" / "clear" | Select all + Backspace |
| "scroll down/up" | SendPointerAction with Wheel |
| "zoom in/out" | SendPointerAction with Pinch |
| "pan left/right" | SendPointerAction with Pan |
| "press key X" | SendKey for the named key |
| "move mouse to X" | SendMousePosition |
| "look around" / "rotate camera" | Lock cursor + SendMouseDelta |

#### Defaults

- **Between steps:** Wait 0.2s minimum for UI to update. Increase for animations or network-dependent UI.
- **Re-discovery:** Re-crawl PlayerGui after any step that is expected to change the UI structure (opening a dialog, navigating to a new screen)
- **Failure handling:** If an element is not found or a click produces no change, report the failure and ask the user — do not silently skip steps
- **Duplicate button state throws** — calling `SendMouseButton(..., true)` when the button is already pressed (or `false` when already released) throws. Always pair press/release for each click.
- **Screenshots:** Save each step as `screenshots/walkthrough_step<N>.png`
- **CoreGUI is restricted** — interactions targeting CoreGUI elements throw a runtime exception
