import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import { makeCliRunFn, spawnBackground, waitForVm, type BackgroundProcess } from "../helpers.js";

describe("isolated play mode (CLI)", () => {
  describe("empty place", () => {
    const PORT = 46260;
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

  // Multiplayer-test launch against a published place via the CLI. Mirrors
  // the empty-place suite (server + two clients) and adds identity +
  // universe-service checks: real PlaceId/GameId match, PlaceVersion
  // populated. Exercises the full download → stage → patch GUID → StartServer
  // → plugin gate → script run chain via the CLI subprocess path.
  describe("published place", () => {
    const PORT = 46261;
    const PLACE_ID = "72824109308551";
    const UNIVERSE_ID = "8612861022";
    let bg: BackgroundProcess;
    const run = makeCliRunFn(PORT);

    beforeAll(async () => {
      bg = spawnBackground([
        "run", "--port", String(PORT),
        "--place", PLACE_ID,
        "--target", "play:server",
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

    it("play:server — game.PlaceId matches the requested placeId", async () => {
      const result = await run({
        target: "play:server",
        showReturn: true,
        source: "return game.PlaceId",
      });
      expect(result.ok).toBe(true);
      expect(result.output).toContain(PLACE_ID);
    });

    it("play:server — game.GameId is the resolved universeId", async () => {
      const result = await run({
        target: "play:server",
        showReturn: true,
        source: "return game.GameId",
      });
      expect(result.ok).toBe(true);
      expect(result.output).toContain(UNIVERSE_ID);
    });

    it("play:server — game.PlaceVersion is non-zero", async () => {
      const result = await run({
        target: "play:server",
        showReturn: true,
        source: "return game.PlaceVersion ~= 0",
      });
      expect(result.ok).toBe(true);
      expect(result.output).toContain("true");
    });

    it("play:server — universe-scoped DataStoreService round-trip succeeds", async () => {
      const result = await run({
        target: "play:server",
        showReturn: true,
        source: `
          local DataStoreService = game:GetService("DataStoreService")
          local ds = DataStoreService:GetDataStore("rodeo_mptest_placeid_probe_cli")
          local stamp = os.time()
          ds:SetAsync("ping", stamp)
          return ds:GetAsync("ping") == stamp
        `,
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

    it("play:client:1 — game.PlaceId matches the published placeId", async () => {
      const result = await run({
        target: "play:client:1",
        showReturn: true,
        source: "return game.PlaceId",
      });
      expect(result.ok).toBe(true);
      expect(result.output).toContain(PLACE_ID);
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
});
