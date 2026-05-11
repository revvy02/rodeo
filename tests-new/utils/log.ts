import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { expect } from "bun:test";

export { extractMarker } from "./markers.js";

/**
 * Log-capture script: prints `MARKER:<guid>` once and returns the marker.
 * The simplest end-to-end check that --logs is wiring print output through
 * to a captured `.log` file in the requested directory.
 */
export const LOG_SCRIPT = `
local HttpService = game:GetService("HttpService")
local marker = HttpService:GenerateGUID(false)
print("MARKER:" .. marker)
return marker
`;

/** All `.log` files under `dir`, decoded to UTF-8. Empty array if dir missing. */
export function readLogFiles(dir: string): Array<{ filename: string; text: string }> {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.endsWith(".log"))
    .filter((name) => statSync(join(dir, name)).isFile())
    .map((name) => ({ filename: name, text: readFileSync(join(dir, name), "utf8") }));
}

/** Assert dir exists, has at least one .log file, and **every** file contains the marker.
 *  Stricter than `some` so a silently-broken per-execution dump task can't be masked
 *  by the launch-time mirror (which captures Studio's full continuous log and would
 *  include the marker as a side effect). */
export function assertLogContainsMarker(dir: string, marker: string): void {
  expect(existsSync(dir)).toBe(true);
  const files = readLogFiles(dir);
  expect(files.length).toBeGreaterThan(0);
  for (const f of files) {
    expect(f.text).toContain(marker);
  }
}

/** Assert each side's marker landed in the right dir and didn't leak into the other. */
export function assertNoLogCrossContamination(dir: string, expected: string, other: string): void {
  expect(existsSync(dir)).toBe(true);
  const files = readLogFiles(dir);
  expect(files.length).toBeGreaterThan(0);
  for (const f of files) {
    expect(f.text).toContain(expected);
    expect(f.text).not.toContain(other);
  }
}
