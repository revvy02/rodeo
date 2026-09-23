import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  waitForProcess,
  waitForDom,
  type BackgroundProcess,
} from "../helpers.js";

const PORT = 46214;

describe("kill spawner (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("killing spawner process kills Studio execution", async () => {
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    const pid = await waitForProcess(PORT, "running");
    expect(pid).not.toBeNull();

    // Kill the spawner CLI process (SIGTERM → WS closes → server auto-kills).
    scriptProc.kill();
    await scriptProc.exited;

    // Wait for the process to no longer be running.
    for (let i = 0; i < 20; i++) {
      const stillRunning = await waitForProcess(PORT, "running", 1000);
      if (stillRunning === null) break;
      await Bun.sleep(500);
    }

    // Verify the DOM is actually free by running a second script.
    // If the first execution wasn't killed in Studio, the DOM pipeline
    // would still be busy and this would hang/timeout.
    const result = runRodeo(["run", "--port", String(PORT), "--source", "return 'freed'"]);
    expect(result.ok).toBe(true);
  });
});
