import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("script file", () => {
  it("runs multi-line script and captures output", async () => {
    const result = await ctx.editDom.runCode({
      source: "print('from file')\nreturn 'ok'",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("from file");
    expect(result.return).toBe("ok");
  });

  it("runs script with show return", async () => {
    const result = await ctx.editDom.runCode({
      source: "return 'directive works'",
    });
    expect(result.ok).toBe(true);
    expect(result.return).toBe("directive works");
  });
});
