import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("kill spawner", () => {
  it("killing a running process frees the VM for new runs", async () => {
    // Start a long-running script
    const runPromise = ctx.editVm.runCode({ source: "task.wait(30) return nil" });

    // Wait until the process is actually running
    let processId: number | undefined;
    for (let i = 0; i < 30; i++) {
      const processes = await ctx.client.listProcesses();
      const running = processes.find((p) => p.state === "running");
      if (running) {
        processId = running.processId;
        break;
      }
      await Bun.sleep(500);
    }
    expect(processId).toBeDefined();

    // Kill the process
    await ctx.client.kill(processId!);
    await runPromise;

    // Verify the VM is actually free by running a second script
    const result = await ctx.editVm.runCode({
      source: "return 'freed'",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("freed");
  });
});
