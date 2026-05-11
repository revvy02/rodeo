import { describe, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { runRodeo } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertLogContainsMarker } from "../../utils/log.js";

const logsDir = ".rodeo/.temp/test-logs-studio";

describe("--logs with Studio (CLI)", () => {
  afterAll(() => rmSync(logsDir, { recursive: true, force: true }));

  it("captures the script's marker print into a single log file", () => {
    rmSync(logsDir, { recursive: true, force: true });

    const result = runRodeo([
      "run", "--place",
      "--port", "46280",
      "--logs", logsDir,
      "--source", LOG_SCRIPT,
    ]);
    expect(result.ok).toBe(true);

    assertLogContainsMarker(logsDir, extractMarker(result.stdout + result.stderr));
  }, 60_000);
});
