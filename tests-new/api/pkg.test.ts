import { describe, beforeAll, afterAll } from "bun:test";
import { smoke, fs, io, process as processTests, roblox } from "../utils/pkgTests.js";
import { studioHandle } from "./helpers.js";

describe("rodeo pkg", () => {
  const studio = studioHandle(46600);
  beforeAll(studio.spawn);
  afterAll(studio.close);

  const run = (opts: Parameters<typeof studio.ctx.editVm.runCode>[0]) => studio.ctx.editVm.runCode(opts);

  describe("smoke", () => smoke(run));
  describe("rodeo.fs", () => fs(run));
  describe("rodeo.io", () => io(run));
  describe("rodeo.process", () => processTests(run));
  describe("rodeo.roblox", () => roblox(run));
});
