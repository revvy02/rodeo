import { describe, it, expect, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupStudio } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertLogContainsMarker } from "../../utils/log.js";
import type { MultiplayerTest } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupStudio();

const logsDir = ".rodeo/.temp/test-logs-play-ts";

// Accepted regression in the studio-first multiplayer path: the play server/
// client run in separate DataModels spawned by ExecuteMultiplayerTestAsync, and
// rodeo only resolves the *edit* Studio's log file (it no longer owns the child
// processes). So per-DataModel --logs capture isn't available for play mode.
// Script stdout still flows over the plugin RPC channel; only Studio log-file
// capture is dropped. Skipped until/unless per-child log capture is reintroduced.
describe.skip("--logs with multiplayer-test mode", () => {
  let mp: MultiplayerTest;

  afterAll(async () => {
    rmSync(logsDir, { recursive: true, force: true });
    await mp.end();
  });

  it("captures the script's marker print into a single log file (play:server)", async () => {
    rmSync(logsDir, { recursive: true, force: true });

    mp = await ctx.studio.startMultiplayerTest(1);

    const result = await mp.server.runCode({ source: LOG_SCRIPT, logs: logsDir });
    expect(result.ok).toBe(true);

    assertLogContainsMarker(logsDir, extractMarker(result.output));
  }, 60_000);
});
