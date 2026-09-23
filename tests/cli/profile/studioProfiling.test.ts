import { describe, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { runRodeo } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertEveryDumpContains } from "../../utils/profiling.js";

const profileDir = ".rodeo/.temp/test-profile-studio";

describe("--profile with Studio (CLI)", () => {
  afterAll(() => rmSync(profileDir, { recursive: true, force: true }));

  it("every dump from a profiled run contains the script's marker", () => {
    rmSync(profileDir, { recursive: true, force: true });

    const result = runRodeo([
      "run", "--place",
      "--port", "46270",
      "--profile", profileDir,
      "--source", PROFILE_SCRIPT,
    ]);
    expect(result.ok).toBe(true);

    assertEveryDumpContains(profileDir, extractMarker(result.stdout + result.stderr));
  }, 60_000);
});
