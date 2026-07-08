import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  waitForProcess,
  waitForDom,
  type BackgroundProcess,
} from "../helpers.js";

const PORT = 46210;

describe("state (CLI)", () => {
  let bg: BackgroundProcess;

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("lists the studio and its DOMs", () => {
    const result = runRodeo(["state", "--port", String(PORT)]);
    expect(result.ok).toBe(true);
    const out = result.stdout + result.stderr;
    expect(out).toContain("STUDIOS");
    expect(out).toContain("edit");
  });

  it("--json exposes studios[].doms[].domId and editDomId", () => {
    const result = runRodeo(["state", "--json", "--port", String(PORT)]);
    expect(result.ok).toBe(true);
    const snap = JSON.parse(result.stdout);
    expect(snap.studios.length).toBeGreaterThan(0);
    const studio = snap.studios[0];
    expect(studio.studioId).toBeTruthy();
    expect(studio.studioMode).toBe("edit");
    expect(studio.doms.length).toBeGreaterThan(0);
    const edit = studio.doms.find((d: any) => d.domKind === "edit");
    expect(edit).toBeTruthy();
    expect(studio.editDomId).toBe(edit.domId);
  });

  it("joins a running run to its DOM and studio", async () => {
    // The run table is live-only: a normal run leaves it the moment it
    // finishes, so assert against a still-running run.
    const scriptProc = spawnBackground([
      "run", "--port", String(PORT), "--source", "task.wait(30) return nil",
    ]);

    try {
      const id = await waitForProcess(PORT, "running");
      expect(id).not.toBeNull();

      const pretty = runRodeo(["state", "--port", String(PORT)]);
      expect(pretty.ok).toBe(true);
      expect(pretty.stdout + pretty.stderr).toContain(id!);
      expect(pretty.stdout + pretty.stderr).toContain("running");

      const json = runRodeo(["state", "--json", "--port", String(PORT)]);
      const snap = JSON.parse(json.stdout);
      const run = (snap.processes ?? []).find((p: any) => p.executionId === id);
      expect(run).toBeTruthy();
      expect(run.context).toBe("plugin");
      expect(run.domId).toBeTruthy();
      expect(run.studioId).toBe(snap.studios[0].studioId);
    } finally {
      scriptProc.kill();
      await scriptProc.exited;
    }
  });

  it("pins a run to a specific DOM via --dom", () => {
    const json = runRodeo(["state", "--json", "--port", String(PORT)]);
    const domId = JSON.parse(json.stdout).studios[0].editDomId;
    expect(domId).toBeTruthy();

    const result = runRodeo([
      "run", "--port", String(PORT), "--dom", domId,
      "--show-return", "--source", "return 'pinned'",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("pinned");
  });
});
