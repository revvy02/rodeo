import { describe, it, expect, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

describe("place id", () => {
  let extraStudio: Studio | undefined;

  afterAll(async () => {
    await extraStudio?.close();
  });

  it("open place by ID and verify PlaceId", async () => {
    const backend = await ctx.client.getLocalStudio();
    extraStudio = await backend.openPlace({
      placeId: 72824109308551,
      background: true,
    });
    const result = await extraStudio.editVm.runCode({
      source: "return game.PlaceId",
    });
    expect(result.ok).toBe(true);
    expect(result.return).toBe(72824109308551);
  });
});
