import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertLogContainsMarker, readLogFiles } from "../../utils/log.js";
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const logsDir = ".rodeo/.temp/test-logs-studio-ts";

let studio: Studio;

describe("--logs with Studio", () => {
  beforeAll(async () => {
    studio = await ctx.backend.open({ background: true });
  });

  afterAll(async () => {
    rmSync(logsDir, { recursive: true, force: true });
    await studio.close();
  });

  it("captures the script's marker print into a single log file", async () => {
    rmSync(logsDir, { recursive: true, force: true });

    const result = await studio.editVm.runCode({ source: LOG_SCRIPT, logs: logsDir });
    expect(result.ok).toBe(true);

    assertLogContainsMarker(logsDir, extractMarker(result.output));
  });

  it("a run with no print materializes an empty log file", async () => {
    rmSync(logsDir, { recursive: true, force: true });

    const result = await studio.editVm.runCode({ source: "return 1", logs: logsDir });
    expect(result.ok).toBe(true);

    const files = readLogFiles(logsDir);
    expect(files.length).toBe(1);
    expect(files[0].text.length).toBe(0);
  });

  it("captures every per-second print across a 10s yielding run", async () => {
    rmSync(logsDir, { recursive: true, force: true });

    const start = Date.now();
    const result = await studio.editVm.runCode({
      source: `
        for i = 1, 10 do
          print("yield-tick-" .. i)
          task.wait(1)
        end
        return "done"
      `,
      logs: logsDir,
    });
    const elapsed = Date.now() - start;

    expect(result.ok).toBe(true);
    expect(elapsed).toBeGreaterThanOrEqual(10_000);

    const files = readLogFiles(logsDir);
    expect(files.length).toBe(1);
    for (let i = 1; i <= 10; i++) {
      expect(files[0].text).toContain(`yield-tick-${i}`);
    }
  }, 30_000);
});
