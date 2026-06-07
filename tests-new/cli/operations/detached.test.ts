import { describe, it, expect } from "bun:test";
import { runRodeo, processMatches, killMatching } from "../helpers.js";

const PORT = 46202;

describe("--detached flag (CLI)", () => {
  it("run --place --detached keeps Studio alive", async () => {
    const result = runRodeo([
      "run", "--place", "--detached",
      "--port", String(PORT),
      "--source", "return nil",
    ]);
    expect(result.ok).toBe(true);

    await Bun.sleep(1000);

    // Studio process should still be running.
    expect(processMatches("RobloxStudio")).toBe(true);

    // Clean up: kill the orphaned Studio launched on this port's temp place.
    killMatching("rodeo-.*\\.rbxl");
    await Bun.sleep(2000);
  });
});
