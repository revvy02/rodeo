import { describe, it, expect, afterAll } from "bun:test";
import { resolve } from "node:path";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

describe("place", () => {
  let extraStudio: Studio | undefined;

  afterAll(async () => {
    await extraStudio?.close();
  });

  it("open empty place and execute inline source", async () => {
    const backend = await ctx.client.getLocalStudio();
    extraStudio = await backend.open({ background: true });
    const result = await extraStudio.editVm.runCode({ source: "return 42" });
    expect(result.ok).toBe(true);
    expect(result.return).toBe(42);
  });

  // A failed Studio launch must reject, not hang. Regression guard for the
  // launch_studio watcher hang: the backend removed the failed instance row
  // from the snapshot, so the watcher (which only resolves on a terminal
  // status) waited forever — see the corrupted-place test in
  // cli/operations/place.test.ts for the full mechanism.
  it("openFile with a corrupted place file rejects with a launch error", async () => {
    const backend = await ctx.client.getLocalStudio();
    await expect(
      backend.openFile(
        resolve("tests-new/fixtures/corrupted_place/place.rbxl"),
        { background: true },
      ),
    ).rejects.toThrow(/launch/);
  }, 30_000);
});
