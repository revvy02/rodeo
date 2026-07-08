import { describe, it, expect } from "bun:test";
import { setupStudio } from "../helpers.js";
const ctx = setupStudio();
describe("kill spawner", () => {
  it("killing a running process frees the VM for new runs", async () => {
    // Start a long-running script
    const runPromise = ctx.editVm.runCode({ source: "task.wait(30) return nil" });

    // Wait until the process is actually running
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

    // Kill the process
    await ctx.client.kill(executionId!);
    await runPromise;

    // Verify the VM is actually free by running a second script
    const result = await ctx.editVm.runCode({
      source: "return 'freed'",
    });
    expect(result.ok).toBe(true);
    expect(result.return).toBe("freed");
  });
});
