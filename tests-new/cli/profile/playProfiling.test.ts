import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { runRodeo, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertEveryDumpContains } from "../../utils/profiling.js";

const PORT = 46276;
const profileDir = ".rodeo/.temp/test-profile-play";

describe("--profile with play mode (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    rmSync(profileDir, { recursive: true, force: true });
    bg = spawnBackground([
      "run", "--port", String(PORT), "--place",
      "--target", "play:server", "--profile",
    ]);
    await waitForVm(PORT);
  });

  afterAll(async () => {
    bg.kill();
    await bg.exited;
    rmSync(profileDir, { recursive: true, force: true });
  });

  it("play:server — every dump contains the script's marker", () => {
    const result = runRodeo([
      "run", "--port", String(PORT),
      "--target", "play:server",
      "--profile", profileDir,
      "--source", PROFILE_SCRIPT,
    ]);
    expect(result.ok).toBe(true);
    assertEveryDumpContains(profileDir, extractMarker(result.stdout + result.stderr));
  }, 60_000);

  it("play:client — every dump contains the script's marker", () => {
    const clientProfileDir = `${profileDir}-client`;
    rmSync(clientProfileDir, { recursive: true, force: true });

    const result = runRodeo([
      "run", "--port", String(PORT),
      "--target", "play:client:1",
      "--profile", clientProfileDir,
      "--source", PROFILE_SCRIPT,
    ]);
    expect(result.ok).toBe(true);
    assertEveryDumpContains(clientProfileDir, extractMarker(result.stdout + result.stderr));

    rmSync(clientProfileDir, { recursive: true, force: true });
  }, 60_000);
});
