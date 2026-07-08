import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  waitForProcess,
  waitForDom,
  type BackgroundProcess,
} from "../helpers.js";

const PORT = 46212;

describe("kill (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("kill terminates running process", async () => {
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    const id = await waitForProcess(PORT, "running");
    expect(id).not.toBeNull();

    const killResult = runRodeo(["kill", id!, "--port", String(PORT)]);
    expect(killResult.ok).toBe(true);
    expect(killResult.stderr).toContain(`Killed ${id}`);

    // The spawner should exit non-zero when its run is killed.
    const exitCode = await Promise.race([
      scriptProc.exited,
      (async () => { await Bun.sleep(10_000); return -1; })(),
    ]);
    expect(exitCode).not.toBe(-1);
    expect(exitCode).not.toBe(0);
  });

  it("kill nonexistent process returns error", () => {
    const result = runRodeo(["kill", "nonexistent", "--port", String(PORT)]);
    expect(result.ok).toBe(false);
    expect(result.stderr).toContain("not found");
  });
});
