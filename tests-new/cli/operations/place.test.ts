import { describe, it, expect } from "bun:test";
import { existsSync, unlinkSync, writeFileSync } from "node:fs";
import { runRodeo } from "../helpers.js";

describe("place (CLI)", () => {
  it("run --place executes inline source", () => {
    const result = runRodeo([
      "run", "--place", "--port", "46204",
      "--source", "return 42", "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("42");
  });

  it("directive --place works", () => {
    const scriptPath = "rodeo-test-place-tmp.luau";
    writeFileSync(
      scriptPath,
      "-- @rodeo run --place\nprint('directive place ok')\nreturn nil",
    );
    try {
      const result = runRodeo(["run", scriptPath]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain("directive place ok");
    } finally {
      if (existsSync(scriptPath)) unlinkSync(scriptPath);
    }
  });
});
