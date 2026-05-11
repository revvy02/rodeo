import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { makeCliRunFn, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";

const PORT = 46200;

describe("auto-connect (CLI)", () => {
  let bg: BackgroundProcess;
  const run = makeCliRunFn(PORT);

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForVm(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("plugin auto-connects on launch", async () => {
    const result = await run({ source: "return 'auto-connected'", showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("auto-connected");
  });
});
