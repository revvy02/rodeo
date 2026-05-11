import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { MultiplayerTestServer, MultiplayerTestClient } from "../../../rodeo-client-ts/src/index.js";

describe("isolated play mode (multi-process)", () => {
  let server: MultiplayerTestServer;
  let client1: MultiplayerTestClient;
  let client2: MultiplayerTestClient;

  beforeAll(async () => {
    server = await ctx.backend.startMultiplayerTest();
  });

  afterAll(async () => {
    await server?.close().catch(() => {});
  });

  it("server — IsRunning is true", async () => {
    const r = await server.runCode({
      source: "return game:GetService('RunService'):IsRunning()",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });

  it("server — no LocalPlayer on server", async () => {
    const r = await server.runCode({
      source: "return game:GetService('Players').LocalPlayer == nil",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });

  it("first client — spawns with LocalPlayer", async () => {
    client1 = await server.connectClient();
    const r = await client1.runCode({
      source: "return game:GetService('Players').LocalPlayer ~= nil",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });

  it("server — sees connected player", async () => {
    const r = await server.runCode({
      source: "return #game:GetService('Players'):GetPlayers() > 0",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });

  it("second client — append spawns another", async () => {
    client2 = await server.connectClient();
    const r = await client2.runCode({
      source: "task.wait(3); return game:GetService('Players').LocalPlayer ~= nil",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });

  it("server — sees two players", async () => {
    const r = await server.runCode({
      source: "return #game:GetService('Players'):GetPlayers() >= 2",
      showReturn: true,
    });
    expect(r.ok).toBe(true);
    expect(r.output).toContain("true");
  });
});
