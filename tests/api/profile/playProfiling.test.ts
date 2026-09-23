import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { PROFILE_SCRIPT, extractMarker, assertEveryDumpContains } from "../../utils/profiling.js";
import type { MultiplayerTestServer, Studio } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const profileDir = ".rodeo/.temp/test-profile-play-ts";

describe("--profile with multiplayer-test mode", () => {
  let studio: Studio;
  let mp: MultiplayerTestServer;

  beforeAll(async () => {
    // Open the edit Studio with profile:true so the multiplayer-test child
    // DataModels (server/clients) inherit the profiler FFlags. They're spawned by
    // Studio's ExecuteMultiplayerTestAsync, not rodeo, so the FFlags must already
    // be present at edit-Studio launch — opening the edit Studio without profile
    // (e.g. via setupStudio) yields no dumps.
    studio = await ctx.backend.open({ profile: true, background: true });
  });

  afterAll(async () => {
    rmSync(profileDir, { recursive: true, force: true });
    await mp?.close();
    await studio?.close();
  });

  it("every dump from a profiled play:server run contains the script's marker", async () => {
    rmSync(profileDir, { recursive: true, force: true });

    mp = await studio.startMultiplayerTest();

    const result = await mp.runCode({ source: PROFILE_SCRIPT, profile: profileDir });
    expect(result.ok).toBe(true);

    assertEveryDumpContains(profileDir, extractMarker(result.output));
  }, 90_000);
});
