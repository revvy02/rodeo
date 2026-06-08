import { describe, it, expect } from "bun:test";
import { setupBackend } from "../helpers.js";
import { RodeoClient } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const IS_WINDOWS = process.platform === "win32";

/** Snapshot the set of running Roblox Studio process IDs. */
function studioPids(): number[] {
  if (IS_WINDOWS) {
    // tasklist via Bun.spawnSync (no shell), so the `/FI` args reach tasklist
    // verbatim. CSV rows look like: "RobloxStudioBeta.exe","12345",...
    const out = Bun.spawnSync({
      cmd: ["tasklist", "/FI", "IMAGENAME eq RobloxStudioBeta.exe", "/FO", "CSV", "/NH"],
    });
    return [...out.stdout.toString().matchAll(/"RobloxStudioBeta\.exe","(\d+)"/g)].map((m) =>
      Number(m[1]),
    );
  }
  const out = Bun.spawnSync({
    cmd: ["pgrep", "-f", "RobloxStudio.app/Contents/MacOS/RobloxStudio"],
  });
  return out.stdout.toString().trim().split("\n").filter(Boolean).map(Number);
}

/** True if a Roblox Studio process with `pid` is running. */
function isAlive(pid: number): boolean {
  if (IS_WINDOWS) {
    const out = Bun.spawnSync({
      cmd: [
        "tasklist",
        "/FI", `PID eq ${pid}`,
        "/FI", "IMAGENAME eq RobloxStudioBeta.exe",
        "/FO", "CSV", "/NH",
      ],
    });
    return out.stdout.toString().includes(`"${pid}"`);
  }
  return Bun.spawnSync({ cmd: ["kill", "-0", String(pid)] }).exitCode === 0;
}

/** Force-kill a process by pid. */
function killPid(pid: number): void {
  if (IS_WINDOWS) {
    Bun.spawnSync({ cmd: ["taskkill", "/F", "/PID", String(pid)] });
  } else {
    Bun.spawnSync({ cmd: ["kill", "-9", String(pid)] });
  }
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

  // Windows-skipped: this asserts a detached Studio outlives a *hard kill of
  // the daemon*. On macOS that holds because NSWorkspace reparents Studios to
  // launchd — they are never children of `rodeo serve`, so SIGKILL can't reach
  // them. On Windows the daemon supervises its children with a Job Object
  // (KILL_ON_JOB_CLOSE): when `rodeo serve` dies the OS tears down the whole
  // tree, including the editor (which — unlike StartServer/StartClient — does
  // not break away from the inherited job). That teardown is exactly what
  // prevents the orphaned-Studio leaks fixed elsewhere in this branch, so
  // "detached survives a daemon hard-kill" is in direct tension with "no
  // orphans on daemon death". Detached still survives the managing *client*'s
  // exit, and close() still kills regardless (test above). Making this case
  // pass on Windows needs a daemon job-breakaway refactor (SILENT_BREAKAWAY_OK
  // + per-Studio job ownership) — deferred as a deliberate design decision.
  it.skipIf(IS_WINDOWS)("detached: true → Studio survives rodeo serve dying", async () => {
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
      const client = await RodeoClient.connect(`http://localhost:${port}`);

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
        killPid(newPid);
      }
    }
  }, 60_000);
});
