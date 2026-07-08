import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("listProcesses", () => {
  it("lists active processes by id", async () => {
    // The process table is live-only: a normal run is removed from the process table the moment
    // it finishes (only --profile runs linger for file transfer), so a
    // just-completed run can't be observed. Assert against a still-running run
    // instead — start a long one and confirm listProcesses lists it by id.
    const runPromise = ctx.editDom.runCode({ source: "task.wait(30) return nil" });
    try {
      let id: string | undefined;
      for (let i = 0; i < 30; i++) {
        const running = (await ctx.client.listProcesses()).find((p) => p.state === "running");
        if (running) { id = running.executionId as string; break; }
        await Bun.sleep(500);
      }
      expect(id).toBeDefined();
      expect(id!.length).toBeGreaterThan(0);
    } finally {
      const running = (await ctx.client.listProcesses()).find((p) => p.state === "running");
      if (running) await ctx.client.kill(running.executionId as string);
      await runPromise.catch(() => {});
    }
  });

  it("shows running process", async () => {
    // Start a long-running script (don't await)
    const runPromise = ctx.editDom.runCode({ source: "task.wait(30) return nil" });

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
      await ctx.client.kill(running.executionId as string);
    }

    // Wait for the run to finish (it was killed)
    await runPromise;
  });
});
