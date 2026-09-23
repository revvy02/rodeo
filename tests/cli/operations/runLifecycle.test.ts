// Run ↔ Studio lifecycle: a --place run owns its Studio, so the Studio's
// fate follows how the run ends — unless --detach breaks the tie.
//
//                     | no --detach            | --detach
//   ended by kill     | studio closes, state   | studio survives, state keeps
//                     | drops run + studio     | studio, drops run
//   ended by exit()   | same as kill           | same as kill
//
// process.exit rides the client-initiated kill path (rodeo-client run.rs),
// so both rows exercise the same teardown; the exit row additionally pins
// the CLI exit code and that nothing after process.exit executes.
//
// Teardown is asserted after a fixed 1s settle — killing a run and closing
// its Studio is expected to be effectively instant; if these flake, that's
// a teardown latency regression to fix, not a reason to wait longer.

import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  waitForProcess,
  processMatches,
  killMatching,
  type BackgroundProcess,
} from "../helpers.js";
import { RodeoClient } from "../../../rodeo-client-ts/src/index.js";

const PORT = 46220;

// task.wait(1) lets the run settle into "running" before exiting; the
// trailing wait must never execute (a real process runs nothing after exit).
const EXIT_SCRIPT = `
local process = require("@rodeo/process")
task.wait(1)
process.exit(0)
task.wait(1000)
`;
const HANG_SCRIPT = "task.wait(9999)";

let serve: BackgroundProcess;

async function getState() {
  const client = await RodeoClient.connect(`http://localhost:${PORT}`);
  try {
    return await client.getState();
  } finally {
    await client.close();
  }
}

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

async function runInState(runId: string): Promise<boolean> {
  const state = await getState();
  return (state.processes ?? []).some(
    (p: any) => p.executionId === runId && p.state === "running",
  );
}

async function studioInState(studioId: string): Promise<boolean> {
  const state = await getState();
  return state.studios.some((s) => s.studioId === studioId);
}

/** The studio a running execution landed on (state join), with the
 * place-file name that identifies its OS process. */
async function studioOf(runId: string) {
  const state = await getState();
  const run = (state.processes ?? []).find((p: any) => p.executionId === runId) as any;
  const studio = state.studios.find((s) => s.studioId === run?.studioId);
  expect(studio).toBeTruthy();
  return { studioId: studio!.studioId, placePattern: escapeRegex(studio!.placeName) };
}

describe("run/studio lifecycle (CLI)", () => {
  beforeAll(async () => {
    serve = spawnBackground(["serve", "--port", String(PORT)]);
    await Bun.sleep(2000);
    await getState(); // throws if the master isn't up
  });
  afterAll(async () => {
    serve.kill();
    await serve.exited;
  });

  it("rodeo kill closes the owned Studio and clears run + studio from state", async () => {
    const proc = spawnBackground(["run", "--port", String(PORT), "--place", "--source", HANG_SCRIPT]);
    const runId = (await waitForProcess(PORT, "running"))!;
    const { studioId, placePattern } = await studioOf(runId);

    expect(runRodeo(["kill", runId, "--port", String(PORT)]).ok).toBe(true);
    await proc.exited;
    await Bun.sleep(1000);

    expect(await runInState(runId)).toBe(false);
    expect(await studioInState(studioId)).toBe(false);
    expect(processMatches(placePattern)).toBe(false);
  });

  it("rodeo kill with --detach: run leaves state, Studio survives", async () => {
    const proc = spawnBackground(["run", "--port", String(PORT), "--place", "--detach", "--source", HANG_SCRIPT]);
    const runId = (await waitForProcess(PORT, "running"))!;
    const { studioId, placePattern } = await studioOf(runId);

    expect(runRodeo(["kill", runId, "--port", String(PORT)]).ok).toBe(true);
    await proc.exited;
    await Bun.sleep(1000);

    expect(await runInState(runId)).toBe(false);
    expect(await studioInState(studioId)).toBe(true);
    expect(processMatches(placePattern)).toBe(true);

    killMatching(placePattern);
    await Bun.sleep(1000);
  });

  it("process.exit closes the owned Studio and clears run + studio from state", async () => {
    const proc = spawnBackground(["run", "--port", String(PORT), "--place", "--source", EXIT_SCRIPT]);
    const runId = (await waitForProcess(PORT, "running"))!;
    const { studioId, placePattern } = await studioOf(runId);

    // exit(0): the CLI ends itself, cleanly — nothing to kill
    expect(await proc.exited).toBe(0);
    await Bun.sleep(1000);

    expect(await runInState(runId)).toBe(false);
    expect(await studioInState(studioId)).toBe(false);
    expect(processMatches(placePattern)).toBe(false);
  });

  it("process.exit with --detach: run leaves state, Studio survives", async () => {
    const proc = spawnBackground(["run", "--port", String(PORT), "--place", "--detach", "--source", EXIT_SCRIPT]);
    const runId = (await waitForProcess(PORT, "running"))!;
    const { studioId, placePattern } = await studioOf(runId);

    expect(await proc.exited).toBe(0);
    await Bun.sleep(1000);

    expect(await runInState(runId)).toBe(false);
    expect(await studioInState(studioId)).toBe(true);
    expect(processMatches(placePattern)).toBe(true);

    killMatching(placePattern);
    await Bun.sleep(1000);
  });
});
