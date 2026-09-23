import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  runRodeo,
  spawnBackground,
  type BackgroundProcess,
} from "../helpers.js";

describe("parallel --place isolation (CLI)", () => {
  it("three parallel places each see their own marker", async () => {
    const ports = ["46220", "46222", "46224"];
    const markers = ["alpha", "beta", "gamma"];

    // Spawn all three concurrently. `Bun.spawnSync` is blocking, so wrapping
    // it in `Promise.resolve(...)` inside `Promise.all` would still serialize
    // them — Bun sees each call to completion before the next map iteration.
    // Use `Bun.spawn` + await `exited` to get genuine parallelism.
    const procs = ports.map((port, i) => {
      const source = `game.Workspace:SetAttribute("__test_marker", "${markers[i]}") return game.Workspace:GetAttribute("__test_marker")`;
      return Bun.spawn([
        "rodeo", "run", "--place", "--port", port,
        "--show-return", "--source", source,
      ], { stdout: "pipe", stderr: "pipe" });
    });

    const exits = await Promise.all(procs.map((p) => p.exited));
    const stdouts = await Promise.all(procs.map((p) => new Response(p.stdout).text()));
    const stderrs = await Promise.all(procs.map((p) => new Response(p.stderr).text()));

    for (let i = 0; i < 3; i++) {
      expect(exits[i]).toBe(0);
      expect(stdouts[i] + stderrs[i]).toContain(markers[i]);
    }
  });
});

describe("token prevents cross-connection (CLI)", () => {
  let procA: BackgroundProcess;
  let procB: BackgroundProcess;
  const portA = 46226;
  const portB = 46228;

  beforeAll(() => {
    procA = spawnBackground(["run", "--port", String(portA), "--place"]);
    procB = spawnBackground(["run", "--port", String(portB), "--place"]);
  });

  afterAll(async () => {
    procA.kill();
    procB.kill();
    await Promise.all([procA.exited, procB.exited]);
  });

  async function getDomCount(port: number): Promise<number> {
    try {
      const resp = await fetch(`http://localhost:${port}/rodeo.MasterService/Health`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      });
      if (!resp.ok) return 0;
      const health = await resp.json() as { totalDoms?: number };
      return health.totalDoms ?? 0;
    } catch {
      return 0;
    }
  }

  it("each server sees exactly 1 DOM", async () => {
    // Wait for both to have a DOM. Windows Studio boots slower than macOS and
    // the two launches serialize through the daemon login-gate slot, so allow
    // up to 45s (macOS breaks out of this loop in a few seconds).
    for (let i = 0; i < 90; i++) {
      if ((await getDomCount(portA)) >= 1 && (await getDomCount(portB)) >= 1) break;
      await Bun.sleep(500);
    }
    // Brief pause for any stray cross-connections to appear.
    await Bun.sleep(2000);

    expect(await getDomCount(portA)).toBe(1);
    expect(await getDomCount(portB)).toBe(1);
  });

  it("scripts execute in the correct Studio", () => {
    const setA = runRodeo([
      "run", "--port", String(portA), "--source",
      `game.Workspace:SetAttribute("__isolation_test", "studio_a") return nil`,
    ]);
    expect(setA.ok).toBe(true);

    const setB = runRodeo([
      "run", "--port", String(portB), "--source",
      `game.Workspace:SetAttribute("__isolation_test", "studio_b") return nil`,
    ]);
    expect(setB.ok).toBe(true);

    const readA = runRodeo([
      "run", "--port", String(portA), "--show-return", "--source",
      `return game.Workspace:GetAttribute("__isolation_test")`,
    ]);
    expect(readA.ok).toBe(true);
    expect(readA.stdout + readA.stderr).toContain("studio_a");

    const readB = runRodeo([
      "run", "--port", String(portB), "--show-return", "--source",
      `return game.Workspace:GetAttribute("__isolation_test")`,
    ]);
    expect(readB.ok).toBe(true);
    expect(readB.stdout + readB.stderr).toContain("studio_b");
  });
});
