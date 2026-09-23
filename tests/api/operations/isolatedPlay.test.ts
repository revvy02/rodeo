import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { setupStudio } from "../helpers.js";
import { RodeoClient } from "../../../rodeo-client-ts/src/index.js";
import type { Studio, MultiplayerTestServer, MultiplayerTestClient } from "../../../rodeo-client-ts/src/index.js";

describe("isolated play mode (multi-process)", () => {
  // Empty-place suite: open an edit Studio (empty place), then start a
  // multiplayer test off it. The returned server is an ordinary Dom handle;
  // players join via mp.connectClient() (each returning its own client Dom
  // handle with .disconnect()), and mp.close() tears the whole test down.
  describe("empty place", () => {
    const ctx = setupStudio();
    let mp: MultiplayerTestServer;
    let c1: MultiplayerTestClient;
    let c2: MultiplayerTestClient;

    beforeAll(async () => {
      mp = await ctx.studio.startMultiplayerTest();
      c1 = await mp.connectClient();
    });

    afterAll(async () => {
      await mp?.close().catch(() => {});
    });

    it("server — IsRunning is true", async () => {
      const r = await mp.runCode({
        source: "return game:GetService('RunService'):IsRunning()",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — no LocalPlayer on server", async () => {
      const r = await mp.runCode({
        source: "return game:GetService('Players').LocalPlayer == nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("first client — spawns with LocalPlayer", async () => {
      const r = await c1.runCode({
        source: "return game:GetService('Players').LocalPlayer ~= nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — sees connected player", async () => {
      const r = await mp.runCode({
        source: "return #game:GetService('Players'):GetPlayers() > 0",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("second client — connectClient spawns another", async () => {
      c2 = await mp.connectClient();
      const r = await c2.runCode({
        source: "task.wait(3); return game:GetService('Players').LocalPlayer ~= nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — sees two players", async () => {
      const r = await mp.runCode({
        source: "return #game:GetService('Players'):GetPlayers() >= 2",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("client disconnect — server sees one player again", async () => {
      await c2.disconnect();
      const r = await mp.runCode({
        source: `
          local Players = game:GetService("Players")
          for _ = 1, 20 do
            if #Players:GetPlayers() == 1 then return true end
            task.wait(0.5)
          end
          return #Players:GetPlayers()
        `,
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });
  });

  // Multiplayer-test launch against a published place. The API has no headless
  // backend entrypoint, so the published place is loaded by opening a Studio
  // on it (openPlace), then starting the multiplayer test off that Studio.
  // Mirrors the empty-place suite (server + two clients) and adds identity +
  // universe-service checks that only make sense for a published place: real
  // PlaceId/GameId match, PlaceVersion populated, DataStoreService universe
  // scope. Uses the same placeId as placeId.test.ts
  // (72824109308551, universe 8612861022).
  describe("published place", () => {
    const PLACE_ID = 72824109308551;
    const UNIVERSE_ID = 8612861022;
    const port = 46420;
    let client: RodeoClient;
    let serverProc: ReturnType<typeof Bun.spawn> | null = null;
    let studio: Studio;
    let mp: MultiplayerTestServer;
    let c1: MultiplayerTestClient;
    let c2: MultiplayerTestClient;

    beforeAll(async () => {
      serverProc = Bun.spawn(
        ["rodeo", "serve", "--port", String(port), "--ppid", String(process.pid)],
        { stderr: "inherit" },
      );
      client = await RodeoClient.connect(`http://localhost:${port}`);
      const backend = await client.getLocalStudio();
      studio = await backend.openPlace({ placeId: PLACE_ID, background: true });
      mp = await studio.startMultiplayerTest();
      c1 = await mp.connectClient();
    });

    afterAll(async () => {
      await mp?.close().catch(() => {});
      await studio?.close().catch(() => {});
      serverProc?.kill();
      await serverProc?.exited;
    });

    it("server — IsRunning is true", async () => {
      const r = await mp.runCode({
        source: "return game:GetService('RunService'):IsRunning()",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — no LocalPlayer on server", async () => {
      const r = await mp.runCode({
        source: "return game:GetService('Players').LocalPlayer == nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — game.PlaceId matches the requested placeId", async () => {
      const r = await mp.runCode({
        source: "return game.PlaceId",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(PLACE_ID);
    });

    it("server — game.GameId is the resolved universeId", async () => {
      const r = await mp.runCode({
        source: "return game.GameId",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(UNIVERSE_ID);
    });

    // Studio-first multiplayer can't set placeVersion: the server is spawned by
    // ExecuteMultiplayerTestAsync from the edit DataModel (PlaceVersion 0), and
    // -task EditPlace ignores -placeVersion (verified). The old path forced it via
    // StartServer's -placeVersion, which rodeo no longer launches. Known limitation
    // — PlaceId/GameId/DataStore still resolve correctly.
    it.skip("server — game.PlaceVersion is non-zero (N/A in studio-first multiplayer)", async () => {
      const r = await mp.runCode({
        source: "return game.PlaceVersion ~= 0",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — universe-scoped DataStoreService round-trip succeeds", async () => {
      const r = await mp.runCode({
        source: `
          local DataStoreService = game:GetService("DataStoreService")
          local ds = DataStoreService:GetDataStore("rodeo_mptest_placeid_probe")
          local stamp = os.time()
          ds:SetAsync("ping", stamp)
          return ds:GetAsync("ping") == stamp
        `,
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("first client — spawns with LocalPlayer", async () => {
      const r = await c1.runCode({
        source: "return game:GetService('Players').LocalPlayer ~= nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("first client — game.PlaceId matches the published placeId", async () => {
      const r = await c1.runCode({
        source: "return game.PlaceId",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(PLACE_ID);
    });

    it("server — sees connected player", async () => {
      const r = await mp.runCode({
        source: "return #game:GetService('Players'):GetPlayers() > 0",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("second client — connectClient spawns another", async () => {
      c2 = await mp.connectClient();
      const r = await c2.runCode({
        source: "task.wait(3); return game:GetService('Players').LocalPlayer ~= nil",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });

    it("server — sees two players", async () => {
      const r = await mp.runCode({
        source: "return #game:GetService('Players'):GetPlayers() >= 2",
      });
      expect(r.ok).toBe(true);
      expect(r.return).toBe(true);
    });
  });
});
