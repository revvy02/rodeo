import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("auto-connect", () => {
  it("plugin auto-connects on launch", async () => {
    const result = await ctx.editVm.runCode({
      source: "return 'auto-connected'",
    });
    expect(result.ok).toBe(true);
    expect(result.return).toBe("auto-connected");
  });
});
