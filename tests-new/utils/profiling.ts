import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { expect } from "bun:test";

export { extractMarker } from "./markers.js";

/**
 * Heartbeat-loop script that emits a per-frame `debug.profilebegin(marker)` /
 * `profileend()` for ~5s. The marker is a fresh GUID minted inside the script
 * (via `HttpService:GenerateGUID`) and printed as `MARKER:<guid>` so the test
 * runner can extract it from output. Returns the marker.
 *
 * Used to verify end-to-end that profiling is actually running and dumps are
 * being collected: every dump captured during the run window should contain
 * the marker.
 */
export const PROFILE_SCRIPT = `
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local marker = HttpService:GenerateGUID(false)
print("MARKER:" .. marker)
local start = os.clock()
while os.clock() - start < 5 do
  RunService.Heartbeat:Wait()
  debug.profilebegin(marker)
  local _ = math.sqrt(123)
  debug.profileend()
end
return marker
`;

/** Sort dump filenames by the frame range AutoCapture embeds in them
 * (`AutoCapture_<ts>_Frames-<start>-<end>.raw`). Lexicographic order breaks
 * once frame numbers change digit count (Frames-999 vs Frames-1000). */
function byFrameOrder(files: string[]): string[] {
  const frameStart = (n: string): number => {
    const m = n.match(/Frames-(\d+)-/);
    return m ? Number(m[1]) : Number.MAX_SAFE_INTEGER;
  };
  return [...files].sort((a, b) => frameStart(a) - frameStart(b));
}

/**
 * Assert dir exists, has at least one .raw dump, and the marker shows up as a
 * contiguous block of dumps.
 *
 * A dump is collected for a run when it contains the plugin's per-frame
 * `rodeo:<execution_id>` label, which the plugin starts stamping BEFORE the
 * user script executes (runtime.luau sets up the profiler connection, then the
 * runner does its init RPCs, then the script reaches its first
 * `debug.profilebegin`). Studio's AutoCapture writes on a fixed 60-frame grid,
 * so the leading dump(s) of a run legitimately cover startup frames that
 * predate the script's first marker — and the trailing dump can cover frames
 * after the marker loop ended. Requiring the marker in EVERY dump therefore
 * flakes on boundary dumps (verified: failing dumps contain the run's own
 * rodeo:<execution_id> label and never the other run's marker).
 *
 * What this asserts instead:
 *  - at least one dump contains the marker (profiling captured script frames
 *    and dumps landed in this run's dir), and
 *  - the marker block is contiguous in frame order (no holes — the script
 *    stamps every Heartbeat, so a gap would indicate lost/misattributed dumps).
 */
export function assertEveryDumpContains(dir: string, marker: string): void {
  expect(existsSync(dir)).toBe(true);
  const files = byFrameOrder(readdirSync(dir).filter((n) => n.endsWith(".raw")));
  expect(files.length).toBeGreaterThan(0);

  const hasMarker = files.map((f) => readFileSync(join(dir, f), "utf8").includes(marker));
  // At least one dump captured the marker loop.
  expect(hasMarker).toContain(true);
  // Contiguous: no marker-less dump between the first and last marker dump.
  const first = hasMarker.indexOf(true);
  const last = hasMarker.lastIndexOf(true);
  const holes = files.filter((_, i) => i > first && i < last && !hasMarker[i]);
  expect(holes).toEqual([]);
}

/** Variant: same contiguity contract as assertEveryDumpContains for the run's
 * own marker, plus NO dump may contain the other concurrent run's marker. */
export function assertNoCrossContamination(dir: string, expected: string, other: string): void {
  assertEveryDumpContains(dir, expected);
  const files = readdirSync(dir).filter((n) => n.endsWith(".raw"));
  for (const f of files) {
    const data = readFileSync(join(dir, f), "utf8");
    expect(data).not.toContain(other);
  }
}
