import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  waitForProcess,
  waitForVm,
  type BackgroundProcess,
} from "../helpers.js";

const PORT = 46210;

describe("ps (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForVm(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("lists completed processes", () => {
    // Run a quick script so there's a completed process to list.
    runRodeo(["run", "--port", String(PORT), "--source", "return nil"]);

    const result = runRodeo(["ps", "--port", String(PORT)]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("done");
  });

  it("shows running process", async () => {
    // Start a long-running script in background.
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    try {
      const pid = await waitForProcess(PORT, "running");
      expect(pid).not.toBeNull();

      const result = runRodeo(["ps", "--port", String(PORT)]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain("running");
    } finally {
      scriptProc.kill();
      await scriptProc.exited;
    }
  });
});
