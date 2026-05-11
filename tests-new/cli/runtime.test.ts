import { describe, beforeAll, afterAll } from "bun:test";
import { execSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import {
  autoTransition,
  bundle,
  cacheRequires,
  cachedRequireTraversal,
  ensureReturn,
  errorHandling,
  execFiltering,
  inlineSource,
  outputFlags,
  targetIdentity,
  uncachedRequireTraversal,
} from "../utils/executionTests.js";
import {
  cliStudioHandle,
  makeCliRunFn,
  spawnBackground,
  waitForVm,
  type BackgroundProcess,
} from "./helpers.js";

describe("rodeo runtime (CLI)", () => {
  const cli = cliStudioHandle(46500);
  beforeAll(cli.spawn);
  afterAll(cli.close);

  describe("inline source", () => inlineSource(cli.runFn));
  describe("ensure return", () => ensureReturn(cli.runFn));
  describe("error handling", () => errorHandling(cli.runFn));
  describe("output flags", () => outputFlags(cli.runFn));
  describe("target identity", () => targetIdentity(cli.runFn));
  describe("auto mode transition", () => autoTransition(cli.runFn));
  describe("target routing and identity", () => execFiltering(cli.runFn));
  describe("bundle", () => bundle(cli.runFn));
});

// ── Fixture-place suites ──────────────────────────────────────────────
// These need their own backgrounded Studio because the place file isn't the
// default empty one — they open rojo-built projects with specific content
// (traversal mutator Script, context-project cache-requires harness).

describe("uncached require traversal (CLI)", () => {
  const FIXTURE = "tests-new/fixtures/traversal-project";
  const PLACE = `${FIXTURE}/place.rbxl`;
  const PORT = 46080;
  let bg: BackgroundProcess;
  beforeAll(async () => {
    execSync(`rojo build ${FIXTURE}/default.project.json -o ${PLACE}`, { stdio: "inherit" });
    bg = spawnBackground(["run", "--port", String(PORT), "--place", PLACE]);
    await waitForVm(PORT);
  });
  afterAll(async () => {
    bg.kill();
    await bg.exited;
    try { if (existsSync(PLACE)) rmSync(PLACE); } catch {}
  });

  uncachedRequireTraversal(makeCliRunFn(PORT));
});

describe("cached require traversal (CLI)", () => {
  const FIXTURE = "tests-new/fixtures/traversal-project";
  const PLACE = `${FIXTURE}/place.rbxl`;
  const PORT = 46082;
  let bg: BackgroundProcess;
  beforeAll(async () => {
    if (!existsSync(PLACE)) {
      execSync(`rojo build ${FIXTURE}/default.project.json -o ${PLACE}`, { stdio: "inherit" });
    }
    bg = spawnBackground(["run", "--port", String(PORT), "--place", PLACE]);
    await waitForVm(PORT);
  });
  afterAll(async () => {
    bg.kill();
    await bg.exited;
    try { if (existsSync(PLACE)) rmSync(PLACE); } catch {}
  });

  cachedRequireTraversal(makeCliRunFn(PORT));
});

describe("target cache requires (CLI)", () => {
  const FIXTURE = "tests-new/fixtures/context-project";
  const PLACE = `${FIXTURE}/place.rbxl`;
  const PORT = 46062;
  let bg: BackgroundProcess;
  beforeAll(async () => {
    execSync(`rojo build ${FIXTURE}/default.project.json -o ${PLACE}`, { stdio: "inherit" });
    bg = spawnBackground(["run", "--port", String(PORT), "--place", PLACE]);
    await waitForVm(PORT);
  });
  afterAll(async () => {
    bg.kill();
    await bg.exited;
    try { if (existsSync(PLACE)) rmSync(PLACE); } catch {}
  });

  cacheRequires(makeCliRunFn(PORT));
});
