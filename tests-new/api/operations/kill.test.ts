import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("kill", () => {
  it("kill terminates running process", async () => {
    // Start a long-running script (don't await)
    const runPromise = ctx.editDom.runCode({ source: "task.wait(30) return nil" });

    // Wait for the process to appear as running
    let executionId: string | undefined;
    for (let i = 0; i < 30; i++) {
      const processes = await ctx.client.listProcesses();
      const running = processes.find((p) => p.state === "running");
      if (running) {
        executionId = running.executionId as string;
        break;
      }
      await Bun.sleep(500);
    }
    expect(executionId).toBeDefined();

    // Kill it
    await ctx.client.kill(executionId!);

    // Wait for the run to finish
    const result = await runPromise;
    expect(result.ok).toBe(false);
  });

  it("kill nonexistent process returns error", async () => {
    await expect(ctx.client.kill("nonexistent")).rejects.toThrow();
  });
});
