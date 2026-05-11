import { describe, it, expect, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertEveryDumpContains } from "../../utils/profiling.js";
import type { MultiplayerTestServer } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const profileDir = ".rodeo/.temp/test-profile-play-ts";

describe("--profile with multiplayer-test mode", () => {
  let server: MultiplayerTestServer;

  afterAll(async () => {
    rmSync(profileDir, { recursive: true, force: true });
    await server.close();
  });

  it("every dump from a profiled play:server run contains the script's marker", async () => {
    rmSync(profileDir, { recursive: true, force: true });

    server = await ctx.backend.startMultiplayerTest({ profile: true });

    const result = await server.runCode({ source: PROFILE_SCRIPT, profile: profileDir });
    expect(result.ok).toBe(true);

    assertEveryDumpContains(profileDir, extractMarker(result.output));
  }, 90_000);
});
