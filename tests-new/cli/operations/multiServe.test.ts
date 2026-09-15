import { describe, it, expect, afterAll } from "bun:test";
import { existsSync } from "node:fs";
import { cliStudioHandle, pluginFileFor, runRodeo, waitUntil } from "../helpers.js";

// Two serves of the same build on different ports, running side by side. Each
// studio backend installs its own `rodeo-<build>-<port>.rbxm`, owns only the
// Studios it launched, and removes its file when it exits. The same
// mechanics let two different builds coexist (crossVersion.test.ts).
const PORT_A = 46296;
const PORT_B = 46298;

type StateJson = { studios?: Array<{ studioId: string; sessionId?: string | null }> };

function stateOf(port: number): StateJson {
  const r = runRodeo(["state", "--port", String(port), "--json"]);
  expect(r.ok).toBe(true);
  return JSON.parse(r.stdout) as StateJson;
}

function ownedStudios(state: StateJson): string[] {
  return (state.studios ?? []).filter((s) => s.sessionId).map((s) => s.studioId);
}

describe("two serves side by side (CLI)", () => {
  const a = cliStudioHandle(PORT_A);
  const b = cliStudioHandle(PORT_B);
  afterAll(async () => {
    await b.close();
    await a.close();
  });

  it("each backend installs its own plugin file and neither sees the other's Studio", async () => {
    await a.spawn();
    expect(existsSync(pluginFileFor(PORT_A))).toBe(true);

    // A long run on A stays live while B comes up alongside it.
    const longRun = a.runFn({ source: "task.wait(15) return 'a-done'" });

    await b.spawn();
    expect(existsSync(pluginFileFor(PORT_B))).toBe(true);
    // B's start-time sweep probed A's master, found the same build alive, and
    // left A's file alone.
    expect(existsSync(pluginFileFor(PORT_A))).toBe(true);

    const bRun = await b.runFn({ source: "return 'b-done'" });
    expect(bRun.ok).toBe(true);
    expect(bRun.return).toBe("b-done");

    const aRun = await longRun;
    expect(aRun.ok).toBe(true);
    expect(aRun.return).toBe("a-done");

    // Owned Studios are exclusive to the serve that launched them: the other
    // build's plugin sees a `rodeoPort` that isn't its own and stays dormant.
    const aState = stateOf(PORT_A);
    const bState = stateOf(PORT_B);
    const [aStudio] = ownedStudios(aState);
    const [bStudio] = ownedStudios(bState);
    expect(aStudio).toBeDefined();
    expect(bStudio).toBeDefined();
    expect((bState.studios ?? []).map((s) => s.studioId)).not.toContain(aStudio);
    expect((aState.studios ?? []).map((s) => s.studioId)).not.toContain(bStudio);
  });

  it("a backend removes its plugin file on exit and leaves the other's", async () => {
    await b.close();
    await waitUntil(() => !existsSync(pluginFileFor(PORT_B)), 20_000, "B's plugin file to be removed");
    expect(existsSync(pluginFileFor(PORT_A))).toBe(true);

    await a.close();
    await waitUntil(() => !existsSync(pluginFileFor(PORT_A)), 20_000, "A's plugin file to be removed");
  });
});
