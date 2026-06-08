import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

// Minimal reprod for the frontmost-keystroke drop fixed in
// launch-control@ea6379f: with only one foregrounded Studio and no sibling
// to steal focus, the target stays continuously Qt::ApplicationActive. In
// the old code Cmd+S went through CGEventPostToPid, which writes to the
// target's private Carbon event queue — a queue Qt drains only on
// inactive→active transitions. No transition = event silently dropped =
// save never fires = 20s test timeout. The fix routes frontmost targets
// through CGEventPost(kCGSessionEventTap), the same path hardware events
// take; NSApp of the frontmost app drains it continuously.
//
// Placed first in the file so it runs with the cleanest possible plugin-dir
// and MCP state — later tests in the suite launch additional Studios whose
// plugin files accumulate in ~/Documents/Roblox/Plugins and can conflict
// with a freshly-launched Studio's boot.
describe("save frontmost Studio (no focus transition)", () => {
  let studio: Studio;

  beforeAll(async () => {
    const backend = await ctx.client.getLocalStudio();
    studio = await backend.open({ background: false });
    
    await studio.editVm.runCode({
        source: "game.Workspace:SetAttribute('frontmost_reprod', 'persisted')",
    });
  });

  afterAll(async () => {
    await studio?.close().catch(() => {});
  });

  it("save() on continuously-frontmost Studio persists state", async () => {
    // Full round-trip: save, then cold-open the saved path and verify the
    // attribute round-tripped. A regression of the keystroke drop hangs
    // here at 20s; a save that silently no-ops without writing is caught
    // by the cold-verify miss on the attribute read.
    const save = await studio.save();
    expect(save.saved).toBe(true);
    expect(save.path).toBeDefined();

    const backend = await ctx.client.getLocalStudio();
    const verify = await backend.openFile(save.path!, { background: true });
   
    const read = await verify.editVm.runCode({
        source: "return game.Workspace:GetAttribute('frontmost_reprod')",
        showReturn: true,
    });
    expect(read.ok).toBe(true);
    expect(read.output).toContain("persisted");

    await verify.close()
  });
});

// Split into per-direction tests sharing setup: opening studioA + studioB +
// setting markers happens once in beforeAll; each `it` only does the save +
// cold-verify for one side. Each test does 1 save + 1 cold-Studio launch,
// which fits comfortably under ~15s.
describe("save targets correct studio with multiple places open", () => {
  let studioA: Studio;
  let studioB: Studio;

  beforeAll(async () => {
    const backend = await ctx.client.getLocalStudio();
    // A foregrounded (owns focus, mirrors lute's --focus). B backgrounded.
    studioA = await backend.open({ background: false });
    studioB = await backend.open({ background: true });

    await studioA.editVm.runCode({
      source: "game.Workspace:SetAttribute('save_target_test', 'from_A')",
    });
    await studioB.editVm.runCode({
      source: "game.Workspace:SetAttribute('save_target_test', 'from_B')",
    });
  });

  afterAll(async () => {
    await studioA?.close().catch(() => {});
    await studioB?.close().catch(() => {});
  });

  it("save B writes B's state to B's file", async () => {
    const saveB = await studioB.save();
    expect(saveB.saved).toBe(true);
    expect(saveB.path).toBeDefined();

    const backend = await ctx.client.getLocalStudio();
    const verify = await backend.openFile(saveB.path!, { background: true });

    const read = await verify.editVm.runCode({
        source: "return game.Workspace:GetAttribute('save_target_test')",
        showReturn: true,
    });
    expect(read.ok).toBe(true);
    expect(read.output).toContain("from_B");
    expect(read.output).not.toContain("from_A");

    await verify.close()

  });

  it("save A writes A's state to A's file", async () => {
    const saveA = await studioA.save();
    expect(saveA.saved).toBe(true);
    expect(saveA.path).toBeDefined();

    const backend = await ctx.client.getLocalStudio();
    const verify = await backend.openFile(saveA.path!, { background: true });

    const read = await verify.editVm.runCode({
        source: "return game.Workspace:GetAttribute('save_target_test')",
        showReturn: true,
    });
    expect(read.ok).toBe(true);
    expect(read.output).toContain("from_A");
    expect(read.output).not.toContain("from_B");

    await verify.close()
  });

  it("A and B save to distinct paths", async () => {
    // Routing check: A and B must save to their own distinct files. The tests
    // above already saved A and B, and re-saving an *unchanged* place is a
    // no-op whose mtime never moves — so save() can't confirm it and times out.
    // Dirty both first so each save is a real write with a confirmable mtime
    // bump. (This also exercises the genuinely-concurrent save path.)
    await Promise.all([
      studioA.editVm.runCode({ source: "game.Workspace:SetAttribute('save_routing', 'A')" }),
      studioB.editVm.runCode({ source: "game.Workspace:SetAttribute('save_routing', 'B')" }),
    ]);
    const [saveA, saveB] = await Promise.all([studioA.save(), studioB.save()]);
    expect(saveA.path).toBeDefined();
    expect(saveB.path).toBeDefined();
    expect(saveA.path).not.toBe(saveB.path);
  });
});

