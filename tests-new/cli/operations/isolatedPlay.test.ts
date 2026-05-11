import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { makeCliRunFn, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";

const PORT = 46260;

describe("isolated play mode (CLI)", () => {
  let bg: BackgroundProcess;
  const run = makeCliRunFn(PORT);

  beforeAll(async () => {
    bg = spawnBackground([
      "run", "--port", String(PORT), "--place", "--target", "play:server",
    ]);
    await waitForVm(PORT);
  });
  afterAll(async () => { bg.kill(); await bg.exited; });

  it("play:server — IsRunning is true", async () => {
    const result = await run({
      target: "play:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning()",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("play:server — no LocalPlayer on server", async () => {
    const result = await run({
      target: "play:server",
      showReturn: true,
      source: "return game:GetService('Players').LocalPlayer == nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("play:client:1 — spawns client with LocalPlayer", async () => {
    const result = await run({
      target: "play:client:1",
      showReturn: true,
      source: "return game:GetService('Players').LocalPlayer ~= nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("play:server — server sees connected player", async () => {
    const result = await run({
      target: "play:server",
      showReturn: true,
      source: "return #game:GetService('Players'):GetPlayers() > 0",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("play:client — append spawns second client", async () => {
    const result = await run({
      target: "play:client",
      showReturn: true,
      source: "task.wait(3); return game:GetService('Players').LocalPlayer ~= nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("play:server — server sees two players", async () => {
    const result = await run({
      target: "play:server",
      showReturn: true,
      source: "return #game:GetService('Players'):GetPlayers() >= 2",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });
});
