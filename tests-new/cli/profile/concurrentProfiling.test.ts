import { describe, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { PROFILE_SCRIPT, extractMarker, assertNoCrossContamination } from "../../utils/profiling.js";

const profileDir1 = ".rodeo/.temp/test-profile-concurrent-1";
const profileDir2 = ".rodeo/.temp/test-profile-concurrent-2";

describe("concurrent --profile runs (CLI)", () => {
  afterAll(() => {
    for (const d of [profileDir1, profileDir2]) rmSync(d, { recursive: true, force: true });
  });

  it("concurrent profiled runs land their own marker in their own dir, no cross-contamination", async () => {
    for (const d of [profileDir1, profileDir2]) rmSync(d, { recursive: true, force: true });

    // Bun.spawn (async) instead of runRodeo (Bun.spawnSync) — wrapping
    // spawnSync inside Promise.all serializes despite the .all wrapper.
    const spawn = (port: string, profileDir: string) =>
      Bun.spawn(
        [
          "rodeo", "run", "--place", "--port", port,
          "--profile", profileDir,
          "--source", PROFILE_SCRIPT,
          "--show-return",
        ],
        { stdout: "pipe", stderr: "pipe" },
      );

    const p1 = spawn("46272", profileDir1);
    const p2 = spawn("46274", profileDir2);

    // Drain stdout/stderr concurrently with .exited so a full pipe buffer
    // can't deadlock either child.
    const [exit1, exit2, out1, err1, out2, err2] = await Promise.all([
      p1.exited,
      p2.exited,
      new Response(p1.stdout).text(),
      new Response(p1.stderr).text(),
      new Response(p2.stdout).text(),
      new Response(p2.stderr).text(),
    ]);

    expect(exit1).toBe(0);
    expect(exit2).toBe(0);

    const marker1 = extractMarker(out1 + err1);
    const marker2 = extractMarker(out2 + err2);
    expect(marker1).not.toBe(marker2);

    assertNoCrossContamination(profileDir1, marker1, marker2);
    assertNoCrossContamination(profileDir2, marker2, marker1);
  }, 120_000);
});
