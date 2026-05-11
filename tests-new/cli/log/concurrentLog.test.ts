import { describe, afterAll, it, expect } from "bun:test";
import { rmSync } from "node:fs";
import { LOG_SCRIPT, extractMarker, assertNoLogCrossContamination } from "../../utils/log.js";

const logsDir1 = ".rodeo/.temp/test-logs-concurrent-1";
const logsDir2 = ".rodeo/.temp/test-logs-concurrent-2";

describe("concurrent --logs runs (CLI)", () => {
  afterAll(() => {
    for (const d of [logsDir1, logsDir2]) rmSync(d, { recursive: true, force: true });
  });

  it("concurrent --logs runs land their own marker in their own dir, no cross-contamination", async () => {
    for (const d of [logsDir1, logsDir2]) rmSync(d, { recursive: true, force: true });

    const spawn = (port: string, dir: string) =>
      Bun.spawn(
        [
          "rodeo", "run", "--place", "--port", port,
          "--logs", dir,
          "--source", LOG_SCRIPT,
          "--show-return",
        ],
        { stdout: "pipe", stderr: "pipe" },
      );

    const p1 = spawn("46284", logsDir1);
    const p2 = spawn("46286", logsDir2);

    const [exit1, exit2, out1, err1, out2, err2] = await Promise.all([
      p1.exited,
      p2.exited,
      new Response(p1.stdout).text(),
      new Response(p1.stderr).text(),
      new Response(p2.stdout).text(),
      new Response(p2.stderr).text(),
    ]);

    expect(exit1).toBe(0);
    expect(exit2).toBe(0);

    const marker1 = extractMarker(out1 + err1);
    const marker2 = extractMarker(out2 + err2);
    expect(marker1).not.toBe(marker2);

    assertNoLogCrossContamination(logsDir1, marker1, marker2);
    assertNoLogCrossContamination(logsDir2, marker2, marker1);
  }, 120_000);
});
