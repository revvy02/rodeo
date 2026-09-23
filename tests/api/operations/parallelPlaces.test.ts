import { describe, it, expect, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

describe("parallel places", () => {
  const studios: Studio[] = [];

  afterAll(async () => {
    for (const s of studios) {
      await s.close().catch(() => {});
    }
  });

  it("three parallel Studios each see their own marker", async () => {
    const backend = await ctx.client.getLocalStudio();
    const markers = ["alpha", "beta", "gamma"];

    // Launch 3 Studios in parallel
    const launches = markers.map(() => backend.open({ background: true }));
    const launched = await Promise.all(launches);
    studios.push(...launched);

    // Set unique markers on each
    for (let i = 0; i < 3; i++) {
      await studios[i].editDom.runCode({
        source: `game.Workspace:SetAttribute("__test_marker", "${markers[i]}") return nil`,
      });
    }

    // Verify each sees its own marker
    for (let i = 0; i < 3; i++) {
      const result = await studios[i].editDom.runCode({
        source: 'return game.Workspace:GetAttribute("__test_marker")',
      });
      expect(result.ok).toBe(true);
      expect(result.return).toBe(markers[i]);
    }
  });
});
