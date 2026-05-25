import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
import type { MultiplayerTestServer, MultiplayerTestClient } from "../../../rodeo-client-ts/src/index.js";

describe("isolated play mode (multi-process)", () => {
  describe("empty place", () => {
    const ctx = setupBackend();
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

  // Multiplayer-test launch against a published place. Mirrors the empty-place
  // suite (server + two clients) and adds identity + universe-service checks
  // that only make sense for a published place: real PlaceId/GameId match,
  // PlaceVersion populated, DataStoreService universe scope. Exercises the
  // full download → stage → patch GUID → StartServer with real ids → plugin
  // gate → script run chain. Uses the same placeId as placeId.test.ts
  // (72824109308551, universe 8612861022).
  describe("published place", () => {
    const ctx = setupBackend();
    const PLACE_ID = 72824109308551;
    const UNIVERSE_ID = 8612861022;
    let server: MultiplayerTestServer;
    let client1: MultiplayerTestClient;
    let client2: MultiplayerTestClient;

    beforeAll(async () => {
      server = await ctx.backend.startMultiplayerTest({ placeId: PLACE_ID });
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

    it("server — game.PlaceId matches the requested placeId", async () => {
      const r = await server.runCode({
        source: "return game.PlaceId",
        showReturn: true,
      });
      expect(r.ok).toBe(true);
      expect(r.output).toContain(String(PLACE_ID));
    });

    it("server — game.GameId is the resolved universeId", async () => {
      const r = await server.runCode({
        source: "return game.GameId",
        showReturn: true,
      });
      expect(r.ok).toBe(true);
      expect(r.output).toContain(String(UNIVERSE_ID));
    });

    it("server — game.PlaceVersion is non-zero", async () => {
      const r = await server.runCode({
        source: "return game.PlaceVersion ~= 0",
        showReturn: true,
      });
      expect(r.ok).toBe(true);
      expect(r.output).toContain("true");
    });

    it("server — universe-scoped DataStoreService round-trip succeeds", async () => {
      const r = await server.runCode({
        source: `
          local DataStoreService = game:GetService("DataStoreService")
          local ds = DataStoreService:GetDataStore("rodeo_mptest_placeid_probe")
          local stamp = os.time()
          ds:SetAsync("ping", stamp)
          return ds:GetAsync("ping") == stamp
        `,
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

    it("first client — game.PlaceId matches the published placeId", async () => {
      const r = await client1.runCode({
        source: "return game.PlaceId",
        showReturn: true,
      });
      expect(r.ok).toBe(true);
      expect(r.output).toContain(String(PLACE_ID));
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
});
