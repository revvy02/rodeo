import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("ps", () => {
  it("lists completed processes", async () => {
    // Run a quick script so there's a completed process
    await ctx.editVm.runCode({ source: "return nil" });

    const processes = await ctx.client.listProcesses();
    const done = processes.find((p) => p.state === "done");
    expect(done).toBeDefined();
  });

  it("shows running process", async () => {
    // Start a long-running script (don't await)
    const runPromise = ctx.editVm.runCode({ source: "task.wait(30) return nil" });

    // Poll until a running process appears
    let found = false;
    for (let i = 0; i < 30; i++) {
      const processes = await ctx.client.listProcesses();
      if (processes.some((p) => p.state === "running")) {
        found = true;
        break;
      }
      await Bun.sleep(500);
    }
    expect(found).toBe(true);

    // Kill the running process
    const processes = await ctx.client.listProcesses();
    const running = processes.find((p) => p.state === "running");
    if (running) {
      await ctx.client.kill(running.processId);
    }

    // Wait for the run to finish (it was killed)
    await runPromise;
  });
});
