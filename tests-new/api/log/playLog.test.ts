import { describe, it, expect, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertLogContainsMarker } from "../../utils/log.js";
import type { MultiplayerTestServer } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const logsDir = ".rodeo/.temp/test-logs-play-ts";

describe("--logs with multiplayer-test mode", () => {
  let server: MultiplayerTestServer;

  afterAll(async () => {
    rmSync(logsDir, { recursive: true, force: true });
    await server.close();
  });

  it("captures the script's marker print into a single log file (play:server)", async () => {
    rmSync(logsDir, { recursive: true, force: true });

    server = await ctx.backend.startMultiplayerTest({});

    const result = await server.runCode({ source: LOG_SCRIPT, logs: logsDir });
    expect(result.ok).toBe(true);

    assertLogContainsMarker(logsDir, extractMarker(result.output));
  }, 60_000);
});
