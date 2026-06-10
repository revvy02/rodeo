import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { existsSync, unlinkSync, writeFileSync } from "node:fs";
import {
  runRodeo,
  spawnBackground,
  waitForVm,
  type BackgroundProcess,
} from "../helpers.js";

describe("place (CLI)", () => {
  it("run --place executes inline source", () => {
    const result = runRodeo([
      "run", "--place", "--port", "46204",
      "--source", "return 42", "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("42");
  });

  it("directive --place works", () => {
    const scriptPath = "rodeo-test-place-tmp.luau";
    writeFileSync(
      scriptPath,
      "-- @rodeo run --place\nprint('directive place ok')\nreturn nil",
    );
    try {
      const result = runRodeo(["run", scriptPath]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain("directive place ok");
    } finally {
      if (existsSync(scriptPath)) unlinkSync(scriptPath);
    }
  });
});

// `rodeo run --place` must GUARANTEE the place is opened.
//
// The launch is gated on serve health, not on whether the requested place is
// open: `place_target.is_some() && !is_healthy(port)`. So when a serve already
// exists on the port, `--place` is silently dropped — no Studio launches and
// the script is routed into whatever place is already resident.
//
// The repro plants a marker attribute in the resident place, then issues a
// second `run --place` (fresh empty place) on the same port and asserts the
// script CANNOT see the resident marker. Bug: it runs inside the resident
// place and reads the marker (and returns in <1s — no launch happened, vs the
// multi-second floor of a real launch). Fixed: a fresh place opens and the
// run is pinned to it, so the marker is nil.
describe("run --place guarantees a place is opened (CLI)", () => {
  const PORT = 46232;
  let bg: BackgroundProcess;

  beforeAll(async () => {
    // Resident serve + Studio on the port, stamped with an identifying marker.
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForVm(PORT);
    const mark = runRodeo([
      "run", "--port", String(PORT), "--source",
      `game.Workspace:SetAttribute("__resident_place", "resident") return nil`,
    ]);
    expect(mark.ok).toBe(true);
  });

  afterAll(async () => {
    bg.kill();
    await bg.exited;
  });

  it("second `run --place` on a busy port executes in its own fresh place", () => {
    const r = runRodeo(
      [
        "run", "--port", String(PORT), "--place",
        "--show-return", "--source",
        `return game.Workspace:GetAttribute("__resident_place") == nil`,
      ],
      { timeout: 120_000 },
    );
    expect(r.ok).toBe(true);
    // In a freshly-opened place the resident marker must not exist.
    expect(r.stdout + r.stderr).toContain("true");
  }, 150_000);
});
