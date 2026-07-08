import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { existsSync, unlinkSync } from "node:fs";
import {
  runRodeo,
  spawnBackground,
  waitForDom,
  type BackgroundProcess,
} from "../helpers.js";

describe("--save flag (CLI)", () => {
  it("run --place --save persists place changes", () => {
    const outPath = ".rodeo-test-save-persist.rbxl";

    const result = runRodeo([
      "run", "--place",
      "--save", outPath,
      "--port", "46240",
      "--source",
      "game.Workspace:SetAttribute('rodeo_test', 'save_works')\nreturn nil",
    ]);
    expect(result.ok).toBe(true);
    expect(existsSync(outPath)).toBe(true);

    const verify = runRodeo([
      "run", "--place", outPath,
      "--port", "46242",
      "--source", "return game.Workspace:GetAttribute('rodeo_test')",
      "--show-return",
    ]);
    expect(verify.ok).toBe(true);
    expect(verify.stdout + verify.stderr).toContain("save_works");

    if (existsSync(outPath)) unlinkSync(outPath);
  });

  it("run --place without --save cleans up temp", () => {
    const result = runRodeo([
      "run", "--place", "--port", "46244",
      "--source", "return nil",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stderr.includes("Saving")).toBe(false);
  });
});

describe("rodeo save (CLI)", () => {
  let bg: BackgroundProcess;
  const PORT = 46246;

  beforeAll(async () => {
    bg = spawnBackground(["run", "--port", String(PORT), "--place"]);
    await waitForDom(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("save persists place changes", () => {
    const modify = runRodeo([
      "run", "--port", String(PORT),
      "--source",
      "game.Workspace:SetAttribute('rodeo_save_cmd', 'it_works')\nreturn nil",
    ]);
    expect(modify.ok).toBe(true);

    const outPath = ".rodeo-test-save-cmd-persist.rbxl";
    const result = runRodeo(["save", "--port", String(PORT), "--out", outPath]);
    expect(result.ok).toBe(true);
    expect(existsSync(outPath)).toBe(true);

    const verify = runRodeo([
      "run", "--place", outPath,
      "--port", "46248",
      "--source", "return game.Workspace:GetAttribute('rodeo_save_cmd')",
      "--show-return",
    ]);
    expect(verify.ok).toBe(true);
    expect(verify.stdout + verify.stderr).toContain("it_works");

    if (existsSync(outPath)) unlinkSync(outPath);
  });
});

describe("save targets correct Studio by PID (CLI)", () => {
  let procA: BackgroundProcess;
  let procB: BackgroundProcess;
  const portA = 46250;
  const portB = 46252;

  beforeAll(async () => {
    procA = spawnBackground(["run", "--port", String(portA), "--place", "--focus"]);
    procB = spawnBackground(["run", "--port", String(portB), "--place"]);
    await Promise.all([waitForDom(portA), waitForDom(portB)]);
  });
  afterAll(async () => {
    procA.kill();
    procB.kill();
    await Promise.all([procA.exited, procB.exited]);
  });

  it("save B while A is focused", () => {
    const modify = runRodeo([
      "run", "--port", String(portB), "--source",
      "game.Workspace:SetAttribute('save_target_test', 'from_B')\nreturn nil",
    ]);
    expect(modify.ok).toBe(true);

    const outPath = ".rodeo-test-save-target.rbxl";
    const save = runRodeo(["save", "--port", String(portB), "--out", outPath]);
    expect(save.ok).toBe(true);
    expect(existsSync(outPath)).toBe(true);

    const verify = runRodeo([
      "run", "--place", outPath, "--port", "46254",
      "--show-return", "--source",
      "return game.Workspace:GetAttribute('save_target_test')",
    ]);
    expect(verify.ok).toBe(true);
    expect(verify.stdout + verify.stderr).toContain("from_B");

    if (existsSync(outPath)) unlinkSync(outPath);
  });
});

describe("rodeo save (no server) (CLI)", () => {
  it("save with no serve running fails", () => {
    const result = runRodeo(["save", "--port", "46999"]);
    expect(result.ok).toBe(false);
  });
});
