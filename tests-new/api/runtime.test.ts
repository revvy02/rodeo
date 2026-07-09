import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { execSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import {
  autoTransition,
  bundle,
  cachedRequireTraversal,
  ensureReturn,
  execFiltering,
  inlineSource,
  outputFlags,
  targetIdentity,
  uncachedRequireTraversal,
} from "../utils/executionTests.js";
import { setupStudio, studioHandle } from "./helpers.js";
import type { Studio } from "../../rodeo-client-ts/src/index.js";

// One Studio backs every factory suite below — mode transitions happen via
// opts.target on each runCode dispatch, so a single edit-DOM handle is enough.

describe("rodeo runtime", () => {
  const studio = studioHandle(46500);
  beforeAll(studio.spawn);
  afterAll(studio.close);

  // Routed (session-scoped) tier: the factories pass mode/context and the
  // master picks the DOM (auto-transitioning the studio's mode as needed).
  const run = (opts: Parameters<typeof studio.ctx.studio.runCode>[0]) => studio.ctx.studio.runCode(opts);

  describe("smoke", () => {
    it("executes a simple script", async () => {
      const result = await run({ source: `print("hello from bun test")` });
      expect(result.ok).toBe(true);
      expect(result.output).toContain("hello from bun test");
    });

    it("returns a value", async () => {
      const result = await run({ source: `return 42`, showReturn: true });
      expect(result.ok).toBe(true);
      expect(result.output).toContain("42");
    });

    it("captures errors", async () => {
      const result = await run({ source: `error("boom")` });
      expect(result.ok).toBe(false);
      expect(result.exitCode).toBe(1);
    });
  });

  describe("inline source", () => inlineSource(run));
  describe("ensure return", () => ensureReturn(run));

  describe("error handling", () => {
    it("error is not ok", async () => {
      const result = await run({ source: "error('intentional failure')" });
      expect(result.ok).toBe(false);
      expect(result.exitCode).toBe(1);
    });

    it("syntax error is not ok", async () => {
      const result = await run({ source: "local = bad syntax +" });
      expect(result.ok).toBe(false);
      expect(result.exitCode).toBe(1);
    });
  });

  describe("output flags", () => outputFlags(run));
  describe("target identity", () => targetIdentity(run));
  describe("auto mode transition", () => autoTransition(run));
  describe("target routing and identity", () => execFiltering(run));
  describe("bundle", () => bundle(run));
});

// ── Fixture-place suites ──────────────────────────────────────────────
// requireTraversal opens a rojo-built place with a mutator Script in SSS, so
// it needs its own Studio (not the shared one above).

const FIXTURE = "tests-new/fixtures/traversal-project";
const PLACE = `${FIXTURE}/place.rbxl`;

function openTraversalStudio(): () => Studio {
  const traversalCtx = setupStudio();
  let traversalStudio: Studio | undefined;
  beforeAll(async () => {
    if (!existsSync(PLACE)) {
      execSync(`rojo build ${FIXTURE}/default.project.json -o ${PLACE}`, { stdio: "inherit" });
    }
    const backend = await traversalCtx.client.getLocalStudio();
    traversalStudio = await backend.openFile(PLACE, { background: true });
  });
  afterAll(async () => {
    await traversalStudio?.close().catch(() => {});
    try { if (existsSync(PLACE)) rmSync(PLACE); } catch {}
  });
  return () => traversalStudio!;
}

describe("uncached require traversal", () => {
  const getStudio = openTraversalStudio();
  uncachedRequireTraversal((opts) => getStudio().runCode(opts));
});

describe("cached require traversal", () => {
  const getStudio = openTraversalStudio();
  cachedRequireTraversal((opts) => getStudio().runCode(opts));
});
