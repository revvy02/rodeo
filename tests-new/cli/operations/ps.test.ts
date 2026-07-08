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

  it("lists active processes by id", async () => {
    // ps is live-only: a normal run is removed from the process table the moment
    // it finishes (only --profile runs linger for file transfer), so a
    // just-completed run can't be observed. Assert against a still-present
    // process instead — spawn a long run and confirm ps lists its id.
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    try {
      const id = await waitForProcess(PORT, "running");
      expect(id).not.toBeNull();

      const result = runRodeo(["ps", "--port", String(PORT)]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain(id!);
    } finally {
      scriptProc.kill();
      await scriptProc.exited;
    }
  });

  it("shows running process", async () => {
    // Start a long-running script in background.
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    try {
      const id = await waitForProcess(PORT, "running");
      expect(id).not.toBeNull();

      const result = runRodeo(["ps", "--port", String(PORT)]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain("running");
    } finally {
      scriptProc.kill();
      await scriptProc.exited;
    }
  });
});
