import { describe, it, expect } from "bun:test";
import { runRodeo, spawnBackground, waitForDom, pidsMatching, waitForPidsGone } from "../helpers.js";

// Studio's temp place is named `rodeo-<uuid>.rbxl` (studio_backend/launch.rs),
// so that pattern identifies a live rodeo Studio. Teardown is async (the run
// client sends CloseStudio; the backend kills Studio off-thread), but the
// measured reap latency is ~2s — so capture the Studio pid and wait
// event-driven for it to exit (Wait-Process on Windows), rather than polling a
// slow CIM query by name (which previously blew past the test timeout).
const RODEO_STUDIO = "rodeo-.*\\.rbxl";
const REAP_TIMEOUT_MS = 20_000;

describe("process cleanup (CLI)", () => {
  it("run --place kills Studio on completion", async () => {
    // Scope to Studios spawned by THIS test: earlier suite files can leave
    // intentionally-orphaned Studios behind (detached flows), and asserting
    // on every rodeo Studio machine-wide makes this test order-dependent.
    const preExisting = new Set(pidsMatching(RODEO_STUDIO));
    const result = runRodeo([
      "run", "--place", "--port", "46216",
      "--source", "return nil", "--show-return",
    ]);
    expect(result.ok).toBe(true);

    // As the one-shot run exits it issues CloseStudio; Studio is mid-teardown.
    // Only wait on pids this run created (already-gone means already reaped).
    const pids = pidsMatching(RODEO_STUDIO).filter((p) => !preExisting.has(p));
    expect(await waitForPidsGone(pids, REAP_TIMEOUT_MS)).toBe(true);
  });

  it("serve --place kills Studio on SIGTERM", async () => {
    const preExisting = new Set(pidsMatching(RODEO_STUDIO));
    const bg = spawnBackground(["run", "--port", "46218", "--place"]);
    await waitForDom(46218);

    // Capture the Studio pid(s) this serve launched, then kill the serve and
    // confirm they're reaped.
    const pids = pidsMatching(RODEO_STUDIO).filter((p) => !preExisting.has(p));
    expect(pids.length).toBeGreaterThan(0);
    bg.kill();
    await bg.exited;
    expect(await waitForPidsGone(pids, REAP_TIMEOUT_MS)).toBe(true);
  });
});
