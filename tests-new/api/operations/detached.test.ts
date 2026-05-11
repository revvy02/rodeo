import { describe, it, expect } from "bun:test";
import { setupBackend } from "../helpers.js";
import { RodeoClient } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

/** Snapshot the set of running Roblox Studio process IDs. */
function studioPids(): number[] {
  const out = Bun.spawnSync({
    cmd: ["pgrep", "-f", "RobloxStudio.app/Contents/MacOS/RobloxStudio"],
  });
  return out.stdout.toString().trim().split("\n").filter(Boolean).map(Number);
}

/** True if a process with `pid` is running. */
function isAlive(pid: number): boolean {
  return Bun.spawnSync({ cmd: ["kill", "-0", String(pid)] }).exitCode === 0;
}

describe("detached", () => {
  it("close() always kills regardless of detached flag", async () => {
    const backend = await ctx.client.getLocalStudio();
    const before = studioPids();

    const studio = await backend.open({ background: true, detached: true });
    await studio.editVm.runCode({ source: "return 'alive'" });

    const newPid = studioPids().find((p) => !before.includes(p))!;
    expect(newPid).toBeDefined();

    await studio.close();
    await Bun.sleep(2000);

    expect(isAlive(newPid)).toBe(false);
  }, 60_000);

  it("detached: true → Studio survives rodeo serve dying", async () => {
    // Spin up a sibling rodeo serve subprocess so we can kill it mid-test
    // without affecting `ctx`. detached's whole point is "outlive the parent" —
    // exercise that path explicitly.
    const port = 46500;
    const proc = Bun.spawn(
      ["rodeo", "serve", "--port", String(port), "--ppid", String(process.pid)],
      { stderr: "inherit" },
    );

    let newPid: number | undefined;
    try {
      const client = new RodeoClient(`http://localhost:${port}`);
      while (!(await client.isHealthy())) await Bun.sleep(500);

      const backend = await client.getLocalStudio();
      const before = studioPids();

      const studio = await backend.open({ background: true, detached: true });
      await studio.editVm.runCode({ source: "return 'alive'" });

      newPid = studioPids().find((p) => !before.includes(p));
      expect(newPid).toBeDefined();

      // Now kill rodeo serve. Studio's `Drop` will fire on the way out;
      // detached: true should skip the kill.
      await client.close();
      proc.kill("SIGKILL");
      await proc.exited;
      await Bun.sleep(2000);

      expect(isAlive(newPid!)).toBe(true);
    } finally {
      // Test owns any surviving process now — kill it explicitly.
      if (newPid !== undefined) {
        Bun.spawnSync({ cmd: ["kill", "-9", String(newPid)] });
      }
    }
  }, 60_000);
});
