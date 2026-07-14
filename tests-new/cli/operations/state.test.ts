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
      // Default route resolves to edit/edit/plugin.
      expect(run.mode).toBe("edit");
      expect(run.domKind).toBe("edit");
      expect(run.context).toBe("plugin");
      expect(run.domId).toBeTruthy();
      expect(run.studioId).toBe(snap.studios[0].studioId);
    } finally {
      scriptProc.kill();
      await scriptProc.exited;
    }
  });

  it("pins a run to a DOM via --dom-id (unique prefix ok)", () => {
    const json = runRodeo(["state", "--json", "--port", String(PORT)]);
    const domId: string = JSON.parse(json.stdout).studios[0].editDomId;
    expect(domId).toBeTruthy();

    // Full id.
    const full = runRodeo([
      "run", "--port", String(PORT), "--dom-id", domId,
      "--show-return", "--source", "return 'pinned'",
    ]);
    expect(full.ok).toBe(true);
    expect(full.stdout + full.stderr).toContain("pinned");

    // 8-char prefix (as shown in the state DOMS table) resolves the same DOM.
    const prefix = runRodeo([
      "run", "--port", String(PORT), "--dom-id", domId.slice(0, 8),
      "--show-return", "--source", "return 'prefix'",
    ]);
    expect(prefix.ok).toBe(true);
    expect(prefix.stdout + prefix.stderr).toContain("prefix");
  });

  it("rejects --dom-id combined with routing flags", () => {
    const json = runRodeo(["state", "--json", "--port", String(PORT)]);
    const domId: string = JSON.parse(json.stdout).studios[0].editDomId;
    const result = runRodeo([
      "run", "--port", String(PORT), "--dom-id", domId, "--mode", "run",
      "--source", "return 1",
    ]);
    expect(result.ok).toBe(false);
  });

  it("--context elevated composes with --dom-id", () => {
    const json = runRodeo(["state", "--json", "--port", String(PORT)]);
    const domId: string = JSON.parse(json.stdout).studios[0].editDomId;
    const result = runRodeo([
      "run", "--port", String(PORT), "--dom-id", domId, "--context", "elevated",
      "--show-return", "--source", "return tostring(DebuggerManager())",
    ]);
    // Elevated needs StudioMCP; assert it at least didn't reject at parse time.
    expect(result.stdout + result.stderr).not.toContain("mode/dom/clients don't apply");
  });

  it("--dom edit routes to the edit DOM", () => {
    const result = runRodeo([
      "run", "--port", String(PORT), "--dom", "edit",
      "--show-return", "--source", "return game:GetService('RunService'):IsEdit()",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("true");
  });

  it("--context server without --mode is rejected (mode never inferred)", () => {
    // mode defaults to edit; (edit, server) has no server DOM, so this fails at
    // validation rather than silently transitioning the studio to run mode.
    const result = runRodeo([
      "run", "--port", String(PORT), "--context", "server",
      "--source", "return 1",
    ]);
    expect(result.ok).toBe(false);
    expect(result.stdout + result.stderr).toContain("edit");
  });
});
