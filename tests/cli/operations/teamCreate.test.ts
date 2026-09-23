// Team Create places (issue #18). Studio's edit DataModel in a Team Create
// session is a network *client* of Roblox's Team Create server, so
// RunService:IsServer() is false there. The plugin used to read that as
// "play client" and wait forever for a unifier nobody creates; the Studio
// never registered and `rodeo run --place <tc place>` hung.
//
// Runs against RODEO_TEAM_CREATE_TEST_PLACE (place 98583678512019, universe
// 10767551972), a dedicated Team-Create-enabled place owned by revvy02.
// Override with RODEO_TEAM_CREATE_PLACE=<placeId>. The launched Studio signs
// in with Studio's automatic login (its primary stored account), so that
// account must be able to edit the place; an account-switched Studio window
// does not change which account a fresh launch gets. Team Create join is
// slower than a local place open, so run with a generous --timeout
// (>= 300000).
//
// After the Team-Create-specific checks, the shared pkg and runtime factory
// suites run against the same Studio, so everything cli/pkg.test.ts and
// cli/runtime.test.ts verify on a plain place is verified in a Team Create
// session too (mode transitions included). pkg runs first: the runtime
// factories leave Studio in a play-test session, and an edit-DOM capture
// while a solo session runs is a black frame the client refuses (issue #17)
// on any place — cli/pkg.test.ts avoids it by using its own Studio. The
// fixture-place suites (require traversal, require polarity) need their own
// place content and are not repeated here. The factories never save or
// publish, and only create unparented or immediately destroyed instances,
// so nothing lands in the synced place.
import { describe, beforeAll, afterAll, it, expect } from "bun:test";
import {
  autoTransition,
  bundle,
  ensureReturn,
  errorHandling,
  execFiltering,
  inlineSource,
  largeSource,
  outputFlags,
  targetIdentity,
} from "../../utils/executionTests.js";
import {
  smoke,
  fs,
  io,
  process as processTests,
  roblox,
  capture,
  images,
  meshes,
} from "../../utils/pkgTests.js";
import { cliStudioHandle } from "../helpers.js";

const PLACE = process.env.RODEO_TEAM_CREATE_PLACE ?? "98583678512019";
const PORT = 46310;

describe("team create place (CLI)", () => {
  const cli = cliStudioHandle(PORT, { place: PLACE, timeoutMs: 180_000 });
  // Before the fix this timed out: the edit plugin never announced, so the
  // launched Studio never registered.
  beforeAll(cli.spawn);
  afterAll(cli.close);

  it("launched Studio registers its edit DOM as domKind edit", () => {
    const launched = cli.studio();
    expect(String(launched.placeId)).toBe(PLACE);
    const kinds = launched.doms.map((d) => d.domKind);
    expect(kinds).toContain("edit");
    expect(kinds).not.toContain("client");
  });

  it("runs in the Team Create edit DOM", async () => {
    // makeCliRunFn pins --studio-id to the one launched Studio on this port.
    const result = await cli.runFn({
      mode: "edit",
      source: `
        local RunService = game:GetService("RunService")
        local ReplicatedStorage = game:GetService("ReplicatedStorage")
        local unifier = ReplicatedStorage:FindFirstChild("RODEO_UNIFIER")
        return {
          placeId = game.PlaceId,
          isEdit = RunService:IsEdit(),
          isServer = RunService:IsServer(),
          isClient = RunService:IsClient(),
          unifierArchivable = if unifier then unifier.Archivable else nil,
        }
      `,
    });
    expect(result.ok, result.output).toBe(true);
    const ret = result.return as Record<string, unknown>;
    expect(ret.placeId).toBe(Number(PLACE));
    expect(ret.isEdit).toBe(true);
    // Sanity: the place really is in a Team Create session. A plain cloud
    // place reports IsServer() == true and would not exercise the bug.
    expect(ret.isServer, `place ${PLACE} is not in a Team Create session`).toBe(false);
    expect(ret.isClient).toBe(true);
    // The unifier is a rodeo artifact in a synced, persisted DataModel: it
    // must not be saved into the cloud place.
    expect(ret.unifierArchivable).toBe(false);
  });

  describe("pkg", () => {
    describe("smoke", () => smoke(cli.runFn));
    describe("rodeo.fs", () => fs(cli.runFn));
    describe("rodeo.io", () => io(cli.runFn));
    describe("rodeo.process", () => processTests(cli.runFn));
    describe("rodeo.roblox", () => roblox(cli.runFn));
    describe("rodeo.capture", () => capture(cli.runFn));
    describe("rodeo.images", () => images(cli.runFn));
    describe("rodeo.meshes", () => meshes(cli.runFn));
  });
  describe("runtime", () => {
    describe("inline source", () => inlineSource(cli.runFn));
    describe("large source", () => largeSource(cli.runFn));
    describe("ensure return", () => ensureReturn(cli.runFn));
    describe("error handling", () => errorHandling(cli.runFn));
    describe("output flags", () => outputFlags(cli.runFn));
    describe("target identity", () => targetIdentity(cli.runFn));
    describe("auto mode transition", () => autoTransition(cli.runFn));
    describe("target routing and identity", () => execFiltering(cli.runFn));
    describe("bundle", () => bundle(cli.runFn));
  });
});
