import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { scriptFile } from "../../utils/executionTests.js";
import { makeCliRunFn, spawnBackground, waitForDom, type BackgroundProcess } from "../helpers.js";
import { mkdirSync, writeFileSync, rmSync } from "node:fs";

const PORT = 46206;

describe("script file (CLI)", () => {
  let bg: BackgroundProcess;
  const run = makeCliRunFn(PORT);
  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  scriptFile(run);

  // `.rodeo/` shorthand: a bare (extensionless) name runs .rodeo/<name>.luau,
  // and the name may include subdirectories — not just a shallow name.
  it("resolves a .rodeo/ shorthand name", async () => {
    writeFileSync(".rodeo/rodeo-shorthand-tmp.luau", "return 'shallow-shorthand'");
    try {
      const result = await run({ file: "rodeo-shorthand-tmp" });
      expect(result.ok).toBe(true);
      expect(result.return).toBe("shallow-shorthand");
    } finally {
      rmSync(".rodeo/rodeo-shorthand-tmp.luau", { force: true });
    }
  });

  it("resolves a nested .rodeo/ shorthand path", async () => {
    mkdirSync(".rodeo/rodeo-shorthand-tmp-dir", { recursive: true });
    writeFileSync(".rodeo/rodeo-shorthand-tmp-dir/nested.luau", "return 'nested-shorthand'");
    try {
      const result = await run({ file: "rodeo-shorthand-tmp-dir/nested" });
      expect(result.ok).toBe(true);
      expect(result.return).toBe("nested-shorthand");
    } finally {
      rmSync(".rodeo/rodeo-shorthand-tmp-dir", { recursive: true, force: true });
    }
  });
});
