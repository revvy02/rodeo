import { describe, it, expect } from "bun:test";
import { runRodeo, spawnBackground } from "../helpers.js";

async function waitForProcessGone(pattern: string, maxAttempts = 20): Promise<boolean> {
  for (let i = 0; i < maxAttempts; i++) {
    const check = Bun.spawnSync(["pgrep", "-f", pattern]);
    if (check.exitCode !== 0) return true;
    await Bun.sleep(500);
  }
  return false;
}

describe("process cleanup (CLI)", () => {
  it("run --place kills Studio on completion", async () => {
    const result = runRodeo([
      "run", "--place", "--port", "46216",
      "--source", "return nil", "--show-return",
    ]);
    expect(result.ok).toBe(true);

    const gone = await waitForProcessGone("rodeo-place-46216");
    expect(gone).toBe(true);
  });

  it("serve --place kills Studio on SIGTERM", async () => {
    const bg = spawnBackground(["run", "--port", "46218", "--place"]);

    await Bun.sleep(5000);
    bg.kill();
    await bg.exited;

    const gone = await waitForProcessGone("rodeo-place-46218");
    expect(gone).toBe(true);
  });
});
