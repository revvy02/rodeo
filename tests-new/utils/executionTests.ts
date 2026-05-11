// Shared execution test cases — port of tests/utils/executionTests.luau.
// Each module is a function taking a `run(opts)` closure that executes against
// some VM (caller chooses: edit:plugin, test:server, run:server, etc). Mode
// transitions are driven by opts.target on every runCode dispatch, so factories
// never need to set Studio mode explicitly.

import { it, expect } from "bun:test";
import { execSync } from "node:child_process";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { RodeoClient } from "../../rodeo-client-ts/src/index.js";
import type { RunCodeOpts, RunResult } from "../../rodeo-client-ts/src/run.js";

export type RunFn = (opts: RunCodeOpts) => Promise<RunResult>;

// ── inlineSource (4 tests) ───────────────────────────────────────────────

export function inlineSource(run: RunFn): void {
  it("inline source returns value with show return", async () => {
    const result = await run({ source: "return 42", showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("42");
  });

  it("inline source returns table", async () => {
    const result = await run({ source: 'return {a=1, b="hello"}', showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("hello");
    expect(result.output).toContain("1");
  });

  it("inline source captures print output", async () => {
    const result = await run({ source: "print('hello from inline')\nreturn nil" });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("hello from inline");
  });

  it("inline source error is not ok", async () => {
    const result = await run({ source: "error('boom')" });
    expect(result.ok).toBe(false);
  });
}

// ── ensureReturn (4 tests) ───────────────────────────────────────────────

export function ensureReturn(run: RunFn): void {
  it("script without return succeeds", async () => {
    const result = await run({ source: "print('no return')" });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("no return");
  });

  it("script with return still works", async () => {
    const result = await run({ source: "return 42", showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("42");
  });

  it("script with only assignments succeeds", async () => {
    const result = await run({ source: "local x = 1\nlocal y = x + 1" });
    expect(result.ok).toBe(true);
  });

  it("script with error still reports error", async () => {
    const result = await run({ source: "error('boom')" });
    expect(result.ok).toBe(false);
  });
}

// ── errorHandling (3 tests) ──────────────────────────────────────────────

export function errorHandling(run: RunFn): void {
  it("error is not ok", async () => {
    const result = await run({ source: "error('intentional failure')" });
    expect(result.ok).toBe(false);
    expect(result.exitCode).toBe(1);
  });

  it("missing script file is not ok", async () => {
    // Lute equivalent: `rodeo run rodeo-nonexistent-script-12345.luau`.
    // TS path: processSource throws synchronously. CLI path: `rodeo run` exits
    // non-zero and returns { ok: false }. Accept either.
    let failed = false;
    try {
      const result = await run({ file: "rodeo-nonexistent-script-12345.luau" });
      failed = !result.ok;
    } catch {
      failed = true;
    }
    expect(failed).toBe(true);
  });

  it("unconnected port is not ok", async () => {
    // Lute equivalent: `rodeo run --source "return 1" --port 59999`
    // Spawn a client pointed at an unused port, assert it can't talk to anything.
    const client = new RodeoClient("http://localhost:59999");
    let healthy = true;
    try {
      healthy = await client.isHealthy();
    } catch {
      healthy = false;
    }
    expect(healthy).toBe(false);
  });
}

// ── outputFlags (3 tests) ────────────────────────────────────────────────
// Mapping from CLI flags to LogFilter per rodeo-cli/src/commands/process_source/execution.rs.

export function outputFlags(run: RunFn): void {
  it("no output suppresses print", async () => {
    const result = await run({
      source: "print('should be hidden')\nreturn nil",
      logFilter: {
        enableWarn: false,
        enableError: false,
        enableInfo: false,
        enableOutput: false,
        enableLogs: false,
      },
    });
    expect(result.ok).toBe(true);
    expect(result.output).not.toContain("should be hidden");
  });

  it("no print suppresses print but allows warn", async () => {
    const result = await run({
      source: "print('hidden') warn('visible')\nreturn nil",
      logFilter: { enableOutput: false },
    });
    expect(result.ok).toBe(true);
    expect(result.output).not.toContain("hidden");
    expect(result.output).toContain("visible");
  });

  it("no warn suppresses warn but allows print", async () => {
    const result = await run({
      source: "print('visible') warn('hidden')\nreturn nil",
      logFilter: { enableWarn: false },
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("visible");
    expect(result.output).not.toContain("hidden");
  });
}

// ── returnFile (2 tests) ─────────────────────────────────────────────────
// TS client has no `--return <path>` analogue; we reproduce the behavior by
// capturing the return via showReturn and writing it to disk ourselves. The
// assertions (file exists, content contains expected text) are unchanged.

function parseShownReturn(output: string): string {
  // Lute's --show-return prints the return value as one line (JSON-ish tostring).
  // We take the last non-empty line as the return payload.
  const lines = output.split("\n").map((l) => l.trim()).filter((l) => l.length > 0);
  return lines[lines.length - 1] ?? "";
}

// User-facing Luau source returning one value of each of the eight Roblox
// types that rodeo-shared/normalize.luau + serialize.luau know how to
// round-trip. Used by the returnFile suite below to exercise every tagged
// emitter at once. Numeric literals are kept simple and distinct so the
// emitted output is unambiguous to substring-assert against.
export const ALL_ROBLOX_TYPES_SOURCE = `return {
  vec3 = Vector3.new(1, 2, 3),
  vec2 = Vector2.new(4, 5),
  cf   = CFrame.new(0, 0, 0),
  c3   = Color3.new(1, 0, 0),
  ud   = UDim.new(0.5, 10),
  ud2  = UDim2.new(0, 100, 0, 50),
  nr   = NumberRange.new(1, 10),
  rect = Rect.new(0, 0, 100, 100),
}`;

function mkTmp(ext: string): string {
  return join(tmpdir(), `rodeo-rt-${randomUUID()}${ext}`);
}

function rmIfExists(path: string): void {
  try { unlinkSync(path); } catch {}
}

export function returnFile(run: RunFn): void {
  it("writes plain table to .luau", async () => {
    const path = mkTmp(".luau");
    try {
      const result = await run({
        source: 'return { value = 42, name = "test" }',
        returnFile: path,
      });
      expect(result.ok).toBe(true);
      expect(existsSync(path)).toBe(true);
      const content = readFileSync(path, "utf-8");
      expect(content.startsWith("return {")).toBe(true);
      expect(content).toContain('["name"] = "test"');
      expect(content).toContain('["value"] = 42');
    } finally {
      rmIfExists(path);
    }
  });

  it("writes plain table to .json", async () => {
    const path = mkTmp(".json");
    try {
      const result = await run({
        source: 'return { value = 42, name = "test" }',
        returnFile: path,
      });
      expect(result.ok).toBe(true);
      const parsed = JSON.parse(readFileSync(path, "utf-8"));
      expect(parsed).toEqual({ value: 42, name: "test" });
    } finally {
      rmIfExists(path);
    }
  });

  it("writes Roblox types to .luau as constructor calls", async () => {
    const path = mkTmp(".luau");
    try {
      const result = await run({ source: ALL_ROBLOX_TYPES_SOURCE, returnFile: path });
      expect(result.ok).toBe(true);
      const content = readFileSync(path, "utf-8");
      // Vector3 emits via `vector.create()` (Luau native vector ctor),
      // Vector2 keeps the Roblox `Vector2.new()` form. See
      // rodeo-shared/serialize.luau TYPE_EMITTERS.
      expect(content).toContain("vector.create(1, 2, 3)");
      expect(content).toContain("Vector2.new(4, 5)");
      expect(content).toContain("CFrame.new(");
      expect(content).toContain("Color3.new(1, 0, 0)");
      expect(content).toContain("UDim.new(0.5, 10)");
      expect(content).toContain("UDim2.new(0, 100, 0, 50)");
      expect(content).toContain("NumberRange.new(1, 10)");
      expect(content).toContain("Rect.new(0, 0, 100, 100)");
    } finally {
      rmIfExists(path);
    }
  });

  it("writes Roblox types to .json as tagged structs", async () => {
    const path = mkTmp(".json");
    try {
      const result = await run({ source: ALL_ROBLOX_TYPES_SOURCE, returnFile: path });
      expect(result.ok).toBe(true);
      const parsed = JSON.parse(readFileSync(path, "utf-8"));
      expect(parsed.vec3).toEqual({ type: "Vector3", value: [1, 2, 3] });
      expect(parsed.vec2).toEqual({ type: "Vector2", value: [4, 5] });
      expect(parsed.cf.type).toBe("CFrame");
      expect(parsed.cf.value).toHaveLength(12);
      expect(parsed.c3).toEqual({ type: "Color3", value: [1, 0, 0] });
      expect(parsed.ud).toEqual({ type: "UDim", value: [0.5, 10] });
      expect(parsed.ud2).toEqual({ type: "UDim2", value: [0, 100, 0, 50] });
      expect(parsed.nr).toEqual({ type: "NumberRange", value: [1, 10] });
      expect(parsed.rect).toEqual({ type: "Rect", value: [0, 0, 100, 100] });
    } finally {
      rmIfExists(path);
    }
  });

  it("round-trips Roblox types through .luau via require", async () => {
    // Project-relative path so darklua's bundle pass can resolve the
    // require. The require resolves at bundle time — Studio just sees the
    // inlined content. A mis-emitted constructor call surfaces here as a
    // parse error or wrong tagged-struct shape after normalize-on-the-way-back.
    const relPathNoExt = `.rodeo/.temp/rodeo-rt-${randomUUID()}`;
    const relPath = `${relPathNoExt}.luau`;
    try {
      const writeResult = await run({ source: ALL_ROBLOX_TYPES_SOURCE, returnFile: relPath });
      expect(writeResult.ok).toBe(true);

      const reloaded = await run({
        source: `return require("./${relPathNoExt}")`,
        showReturn: true,
      });
      expect(reloaded.ok).toBe(true);
      const parsed = JSON.parse(parseShownReturn(reloaded.output));
      expect(parsed.vec3.type).toBe("Vector3");
      expect(parsed.vec3.value).toEqual([1, 2, 3]);
      expect(parsed.cf.type).toBe("CFrame");
      expect(parsed.c3).toEqual({ type: "Color3", value: [1, 0, 0] });
    } finally {
      rmIfExists(relPath);
    }
  });
}

// ── scriptFile (2 tests) ─────────────────────────────────────────────────

export function scriptFile(run: RunFn): void {
  it("runs luau file and captures output", async () => {
    const path = "rodeo-test-script-tmp.luau";
    writeFileSync(path, "print('from file')\nreturn 'ok'");
    try {
      const result = await run({ file: path, showReturn: true });
      expect(result.ok).toBe(true);
      expect(result.output).toContain("from file");
      expect(result.output).toContain("ok");
    } finally {
      unlinkSync(path);
    }
  });

  it("directive enables show return", async () => {
    // Relies on __process_source honoring `--@rodeo run --show-return`
    // header directive so show-return is auto-applied.
    const path = "rodeo-test-directive-tmp.luau";
    writeFileSync(path, "--@rodeo run --show-return\nreturn 'directive works'");
    try {
      const result = await run({ file: path });
      expect(result.ok).toBe(true);
      expect(result.output).toContain("directive works");
    } finally {
      unlinkSync(path);
    }
  });
}

// ── targetIdentity (8 tests) ─────────────────────────────────────────────
// Mirrors executionTests.luau targetIdentity — elevated tests first (require
// pure edit mode so MCP's execute_luau routes to the edit DataModel).

export function targetIdentity(run: RunFn): void {
  it("edit:elevated can access DebuggerManager", async () => {
    const result = await run({
      target: "edit:elevated",
      source: "return tostring(DebuggerManager())",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("DebuggerManager");
  });

  it("edit:elevated can use @rodeo/fs", async () => {
    const result = await run({
      target: "edit:elevated",
      source: 'return require("@rodeo/fs").exists(".")',
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("edit:elevated can use @rodeo/process", async () => {
    const result = await run({
      target: "edit:elevated",
      source: 'local r = require("@rodeo/process").run({"echo", "hi"}) return r.ok',
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("edit:elevated propagates errors", async () => {
    const result = await run({ target: "edit:elevated", source: 'error("boom")' });
    expect(result.ok).toBe(false);
  });

  it("plugin identity works in edit mode (no target)", async () => {
    const result = await run({
      source: "return typeof(game) == 'Instance'",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("run:server can access ServerStorage", async () => {
    const result = await run({
      target: "run:server",
      source: "return game:GetService('ServerStorage') ~= nil",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("test:client can access LocalPlayer", async () => {
    const result = await run({
      target: "test:client",
      source: "return game:GetService('Players').LocalPlayer ~= nil",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("run:server cannot access LocalPlayer", async () => {
    const result = await run({
      target: "run:server",
      source: "return game:GetService('Players').LocalPlayer == nil",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });
}

// ── cacheRequires (2 tests) ──────────────────────────────────────────────

export function cacheRequires(run: RunFn): void {
  it("run:server sees mutated global state with cache-requires", async () => {
    const result = await run({
      target: "run:server",
      cacheRequires: true,
      source: "return require(game.ReplicatedStorage.globalState).value",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });

  it("test:client sees mutated global state with cache-requires", async () => {
    const result = await run({
      target: "test:client",
      cacheRequires: true,
      source: "return require(game.ReplicatedStorage.globalState).value",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });
}

// ── execFiltering (11 tests) ─────────────────────────────────────────────

const SOURCE_VM = `
    local RS = game:GetService('RunService')
    return {
        studio = RS:IsStudio(),
        server = RS:IsServer(),
        client = RS:IsClient(),
        running = RS:IsRunning()
    }
`;

const SOURCE_PLUGIN = `
    local RS = game:GetService('RunService')
    return {
        edit = RS:IsEdit(),
        studio = RS:IsStudio(),
        server = RS:IsServer(),
        client = RS:IsClient(),
        running = RS:IsRunning()
    }
`;

export function execFiltering(run: RunFn): void {
  // Edit mode tests

  it("edit:plugin targets edit VM", async () => {
    const result = await run({ target: "edit:plugin", source: SOURCE_PLUGIN, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"edit":true');
    expect(result.output).toContain('"running":false');
  });

  it("edit:plugin can call IsEdit", async () => {
    const result = await run({
      target: "edit:plugin",
      source: "return game:GetService('RunService'):IsEdit()",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("no target matches any VM", async () => {
    const result = await run({ source: SOURCE_PLUGIN, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"studio":true');
  });

  // Run mode tests

  it("run:server targets server VM in run mode", async () => {
    const result = await run({ target: "run:server", source: SOURCE_VM, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"running":true');
    expect(result.output).toContain('"server":true');
  });

  it("run:server runs as Script (can access ServerStorage)", async () => {
    const result = await run({
      target: "run:server",
      source: "return game:GetService('ServerStorage') ~= nil",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("run:server:plugin runs as ModuleScript on server VM", async () => {
    const result = await run({ target: "run:server:plugin", source: SOURCE_PLUGIN, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"running":true');
    expect(result.output).toContain('"server":true');
    expect(result.output).toContain('"edit":');
  });

  // Play/test mode tests

  it("test:server targets server VM in play mode", async () => {
    const result = await run({ target: "test:server", source: SOURCE_VM, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"running":true');
    expect(result.output).toContain('"server":true');
  });

  it("test:server:plugin runs as ModuleScript on server VM", async () => {
    const result = await run({ target: "test:server:plugin", source: SOURCE_PLUGIN, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"running":true');
    expect(result.output).toContain('"server":true');
    expect(result.output).toContain('"edit":');
  });

  it("test:client targets client VM in play mode", async () => {
    const result = await run({ target: "test:client", source: SOURCE_VM, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"client":true');
    expect(result.output).toContain('"running":true');
  });

  it("test:client runs as LocalScript (can access LocalPlayer)", async () => {
    const result = await run({
      target: "test:client",
      source: "return game:GetService('Players').LocalPlayer ~= nil",
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("test:client:plugin runs as ModuleScript on client VM", async () => {
    const result = await run({ target: "test:client:plugin", source: SOURCE_PLUGIN, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"running":true');
    expect(result.output).toContain('"client":true');
    expect(result.output).toContain('"edit":');
  });
}

// ── uncachedRequireTraversal (6 tests) ───────────────────────────────────

export function uncachedRequireTraversal(run: RunFn): void {
  const exec = (source: string) =>
    run({
      target: "run:server",
      source,
      showReturn: true,
      verbose: true,
    });

  it("leaf require gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.leaf).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });

  it("sibling require gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.mid).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });

  it("sibling transitive dep gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.mid).leaf.value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });

  it("@self require gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.deep).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });

  it("ancestor require gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.deep).child.value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });

  it("ancestor transitive dep gets fresh state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.deep).child.leaf.value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("original");
  });
}

// ── cachedRequireTraversal (4 tests) ─────────────────────────────────────

export function cachedRequireTraversal(run: RunFn): void {
  const exec = (source: string) =>
    run({
      target: "run:server",
      source,
      showReturn: true,
      verbose: true,
      cacheRequires: true,
    });

  it("leaf require sees mutated state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.leaf).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });

  it("sibling require sees mutated state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.mid).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });

  it("@self require sees mutated state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.deep).value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });

  it("ancestor transitive dep sees mutated state", async () => {
    const result = await exec("return require(game.ReplicatedStorage.deep).child.leaf.value");
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mutated");
  });
}

// ── autoTransition (6 tests) ─────────────────────────────────────────────
// Verifies that passing `target: "run:server" | "test:client" | ...` to runCode
// triggers the expected mode transition. Order of cases matters — they traverse
// edit→run→test→run with specific expectations at each hop.

export function autoTransition(run: RunFn): void {
  it("edit → run:server auto-enters run mode", async () => {
    const result = await run({
      target: "run:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning() and game.Players.LocalPlayer == nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("run → test:client auto-transitions to play mode", async () => {
    const result = await run({
      target: "test:client",
      showReturn: true,
      source: "return game:GetService('Players').LocalPlayer ~= nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("test → run:server auto-transitions back to run mode", async () => {
    const result = await run({
      target: "run:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning() and game:GetService('ServerStorage') ~= nil",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("no transition when already in correct mode", async () => {
    const result = await run({
      target: "run:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning()",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("run → test:server auto-transitions to play mode", async () => {
    const result = await run({
      target: "test:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning() and #game:GetService('Players'):GetPlayers() > 0",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("test → run:server auto-transitions to run mode", async () => {
    const result = await run({
      target: "run:server",
      showReturn: true,
      source: "return game:GetService('RunService'):IsRunning() and #game:GetService('Players'):GetPlayers() == 0 and 'PASS' or 'FAIL'",
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("PASS");
  });
}

// ── bundle (12 tests) ────────────────────────────────────────────────────
// Drives scripts through the bundle/require-resolver pipeline using fixture
// files under tests-new/fixtures/resolve/. The "missing script" case accepts
// either behavior: the api path throws from runCode, the CLI path returns a
// non-ok result — both are valid failure modes.

export function bundle(run: RunFn): void {
  const FIXTURES = "tests-new/fixtures/resolve";

  it("resolves @rodeo/* requires", async () => {
    const result = await run({ file: `${FIXTURES}/rodeo-alias.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("resolved");
    expect(result.output).toContain("alias_ok");
  });

  it("resolves external local dep", async () => {
    const result = await run({ file: `${FIXTURES}/ext-main.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("from_helper");
  });

  it("resolves nested external dep", async () => {
    const result = await run({ file: `${FIXTURES}/nested-main.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("nested_ok");
  });

  it("resolves package with internal requires", async () => {
    const result = await run({ file: `${FIXTURES}/pkg-internal.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("5");
  });

  it("resolves cross-directory require", async () => {
    const result = await run({ file: `${FIXTURES}/cross-dir.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("cross_dir_ok");
  });

  it("resolves deep transitive chain", async () => {
    const result = await run({ file: `${FIXTURES}/transitive.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("transitive_ok");
  });

  it("resolves @lune/* shims", async () => {
    const result = await run({ file: `${FIXTURES}/lune-shim.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("lune_shim_ok");
    expect(result.output).toContain("cwd:");
  });

  it("resolves mixed @rodeo + relative + @lune requires", async () => {
    const result = await run({ file: `${FIXTURES}/mixed-requires.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("mixed:from_helper:");
    expect(result.output).toContain("mixed_ok");
  });

  it("bundles script with no requires", async () => {
    const result = await run({ file: `${FIXTURES}/no-deps.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("no_deps_ok");
  });

  it("bundles via @rodeo run directive", async () => {
    const result = await run({ file: `${FIXTURES}/directive-bundle.luau`, showReturn: true });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("directive_ok");
  });

  it("excludes in-game deps via sourcemap", async () => {
    const smDir = `${FIXTURES}/sourcemap-test`;
    execSync(`rojo sourcemap ${smDir}/default.project.json -o ${smDir}/sourcemap.json`, { stdio: "inherit" });
    const result = await run({
      file: `${smDir}/main.luau`,
      sourcemap: `${smDir}/sourcemap.json`,
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("sm:");
    expect(result.output).toContain("from_helper");
  });

  it("fails on missing script", async () => {
    let threw = false;
    let result: RunResult | undefined;
    try {
      result = await run({ file: "nonexistent-script-12345.luau" });
    } catch {
      threw = true;
    }
    // api runCode throws; CLI returns non-ok — accept both.
    expect(threw || (result !== undefined && !result.ok)).toBe(true);
  });
}
