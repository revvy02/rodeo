import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { existsSync, readFileSync, unlinkSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import {
  runRodeo,
  spawnBackground,
  waitForDom,
  type BackgroundProcess,
} from "../helpers.js";

// CLI variant of utils/executionTests.ts returnValueCap — direct runRodeo
// invocations because makeCliRunFn always shadows returns through a temp
// --return file, which keeps the wire field (the thing being capped) empty.
// The cap exists because the in-wire return value rides the done message,
// a single unchunkable hop with a hard transport limit; an oversized one
// used to kill the backend↔master stream (hang) or silently vanish (exit 0).
const PORT = 46212;
const CAP = 2 * 1024 * 1024;

describe("return value wire cap (CLI)", () => {
  let bg: BackgroundProcess;
  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("over-cap return value fails with an actionable error", () => {
    const r = runRodeo([
      "run", "--port", String(PORT),
      "--source", `return string.rep("a", ${CAP + 65536})`,
    ], { timeout: 60_000 });
    expect(r.ok).toBe(false);
    expect(r.stdout + r.stderr).toContain("return value too large");
    expect(r.stdout + r.stderr).toContain("--return");
  }, 90_000);

  it("over-cap with --show-return prints the value and stays successful", () => {
    const r = runRodeo([
      "run", "--port", String(PORT), "--show-return",
      "--source", `return "S__" .. string.rep("a", ${CAP + 65536}) .. "__E"`,
    ], { timeout: 60_000 });
    expect(r.ok).toBe(true);
    expect(r.stdout).toContain("S__");
    expect(r.stdout).toContain("__E");
    expect(r.stderr).toContain("omitted from result.return");
  }, 90_000);

  it("over-cap return value succeeds through a --return file", () => {
    const path = join(tmpdir(), `rodeo-cap-${randomUUID()}.json`);
    try {
      const r = runRodeo([
        "run", "--port", String(PORT), "--return", path,
        "--source", `return string.rep("a", ${CAP + 65536})`,
      ], { timeout: 60_000 });
      expect(r.ok).toBe(true);
      // JSON of an all-ASCII string is the string plus two quotes.
      expect(readFileSync(path, "utf-8").length).toBe(CAP + 65536 + 2);
    } finally {
      if (existsSync(path)) unlinkSync(path);
    }
  }, 90_000);
});
