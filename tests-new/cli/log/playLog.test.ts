import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { runRodeo, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertLogContainsMarker } from "../../utils/log.js";

const PORT = 46282;
const logsDir = ".rodeo/.temp/test-logs-play";

// Accepted regression in the studio-first multiplayer path: the play server/
// client run in separate DataModels spawned by ExecuteMultiplayerTestAsync, and
// rodeo only resolves the *edit* Studio's log file (it no longer owns the child
// processes). So per-DataModel --logs capture isn't available for play mode.
// Script stdout still flows over the plugin RPC channel; only Studio log-file
// capture is dropped. Skipped until/unless per-child log capture is reintroduced.
describe.skip("--logs with play mode (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    rmSync(logsDir, { recursive: true, force: true });
    bg = spawnBackground([
      "run", "--port", String(PORT), "--place",
      "--target", "play:server",
    ]);
    await waitForVm(PORT);
  });

  afterAll(async () => {
    bg.kill();
    await bg.exited;
    rmSync(logsDir, { recursive: true, force: true });
  });

  it("play:server — captures the script's marker print", () => {
    const result = runRodeo([
      "run", "--port", String(PORT),
      "--target", "play:server",
      "--logs", logsDir,
      "--source", LOG_SCRIPT,
    ]);
    expect(result.ok).toBe(true);
    assertLogContainsMarker(logsDir, extractMarker(result.stdout + result.stderr));
  }, 60_000);

  it("play:client — captures the script's marker print", () => {
    const clientLogsDir = `${logsDir}-client`;
    rmSync(clientLogsDir, { recursive: true, force: true });

    const result = runRodeo([
      "run", "--port", String(PORT),
      "--target", "play:client:1",
      "--logs", clientLogsDir,
      "--source", LOG_SCRIPT,
    ]);
    expect(result.ok).toBe(true);
    assertLogContainsMarker(clientLogsDir, extractMarker(result.stdout + result.stderr));

    rmSync(clientLogsDir, { recursive: true, force: true });
  }, 60_000);
});
