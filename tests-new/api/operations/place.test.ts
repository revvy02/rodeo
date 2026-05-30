import { describe, it, expect, afterAll } from "bun:test";
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
});
