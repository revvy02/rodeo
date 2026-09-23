import { describe, it, expect, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertNoCrossContamination } from "../../utils/profiling.js";
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const profileDir1 = ".rodeo/.temp/test-profile-concurrent-1-ts";
const profileDir2 = ".rodeo/.temp/test-profile-concurrent-2-ts";

describe("concurrent profile runs", () => {
  const studios: Studio[] = [];

  afterAll(async () => {
    for (const d of [profileDir1, profileDir2]) rmSync(d, { recursive: true, force: true });
    for (const s of studios) await s.close();
  });

  it("concurrent profiled runs land their own marker in their own dir, no cross-contamination", async () => {
    for (const d of [profileDir1, profileDir2]) rmSync(d, { recursive: true, force: true });

    const [studio1, studio2] = await Promise.all([
      ctx.backend.open({ profile: true, background: true }),
      ctx.backend.open({ profile: true, background: true }),
    ]);
    studios.push(studio1, studio2);

    const [result1, result2] = await Promise.all([
      studio1.editDom.runCode({ source: PROFILE_SCRIPT, profile: profileDir1 }),
      studio2.editDom.runCode({ source: PROFILE_SCRIPT, profile: profileDir2 }),
    ]);

    expect(result1.ok).toBe(true);
    expect(result2.ok).toBe(true);

    const marker1 = extractMarker(result1.output);
    const marker2 = extractMarker(result2.output);
    expect(marker1).not.toBe(marker2);

    assertNoCrossContamination(profileDir1, marker1, marker2);
    assertNoCrossContamination(profileDir2, marker2, marker1);
  }, 120_000);
});
