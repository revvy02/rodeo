import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertEveryDumpContains } from "../../utils/profiling.js";
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const profileDir = ".rodeo/.temp/test-profile-studio-ts";

let profileStudio: Studio;

describe("--profile with Studio", () => {
  beforeAll(async () => {
    profileStudio = await ctx.backend.open({ profile: true, background: true });
  });

  afterAll(async () => {
    rmSync(profileDir, { recursive: true, force: true });
    await profileStudio.close();
  });

  it("every dump from a profiled run contains the script's marker", async () => {
    rmSync(profileDir, { recursive: true, force: true });

    const result = await profileStudio.editDom.runCode({ source: PROFILE_SCRIPT, profile: profileDir });
    expect(result.ok).toBe(true);

    assertEveryDumpContains(profileDir, extractMarker(result.output));
  }, 60_000);
});
