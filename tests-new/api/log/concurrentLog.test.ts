import { describe, it, expect, afterAll } from "bun:test";
import { rmSync } from "node:fs";
import { setupBackend } from "../helpers.js";
import { LOG_SCRIPT, extractMarker, assertNoLogCrossContamination } from "../../utils/log.js";
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

const ctx = setupBackend();

const logsDir1 = ".rodeo/.temp/test-logs-concurrent-1-ts";
const logsDir2 = ".rodeo/.temp/test-logs-concurrent-2-ts";

describe("concurrent --logs runs", () => {
  const studios: Studio[] = [];

  afterAll(async () => {
    for (const d of [logsDir1, logsDir2]) rmSync(d, { recursive: true, force: true });
    for (const s of studios) await s.close();
  });

  it("concurrent --logs runs land their own marker in their own dir, no cross-contamination", async () => {
    for (const d of [logsDir1, logsDir2]) rmSync(d, { recursive: true, force: true });

    const [studio1, studio2] = await Promise.all([
      ctx.backend.open({ background: true }),
      ctx.backend.open({ background: true }),
    ]);
    studios.push(studio1, studio2);

    const [result1, result2] = await Promise.all([
      studio1.editVm.runCode({ source: LOG_SCRIPT, logs: logsDir1 }),
      studio2.editVm.runCode({ source: LOG_SCRIPT, logs: logsDir2 }),
    ]);

    expect(result1.ok).toBe(true);
    expect(result2.ok).toBe(true);

    const marker1 = extractMarker(result1.output);
    const marker2 = extractMarker(result2.output);
    expect(marker1).not.toBe(marker2);

    assertNoLogCrossContamination(logsDir1, marker1, marker2);
    assertNoLogCrossContamination(logsDir2, marker2, marker1);
  }, 90_000);
});
