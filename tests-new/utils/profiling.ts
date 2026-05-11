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

/** Assert dir exists, has at least one .raw file, and every file contains the marker. */
export function assertEveryDumpContains(dir: string, marker: string): void {
  expect(existsSync(dir)).toBe(true);
  const files = readdirSync(dir).filter((n) => n.endsWith(".raw"));
  expect(files.length).toBeGreaterThan(0);
  for (const f of files) {
    const data = readFileSync(join(dir, f), "utf8");
    expect(data).toContain(marker);
  }
}

/** Variant: assert marker is present in every dump AND the other marker is absent. */
export function assertNoCrossContamination(dir: string, expected: string, other: string): void {
  expect(existsSync(dir)).toBe(true);
  const files = readdirSync(dir).filter((n) => n.endsWith(".raw"));
  expect(files.length).toBeGreaterThan(0);
  for (const f of files) {
    const data = readFileSync(join(dir, f), "utf8");
    expect(data).toContain(expected);
    expect(data).not.toContain(other);
  }
}
