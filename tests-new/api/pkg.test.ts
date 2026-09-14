import { describe, beforeAll, afterAll } from "bun:test";
import { smoke, fs, io, process as processTests, roblox, capture, images, meshes } from "../utils/pkgTests.js";
import { studioHandle } from "./helpers.js";

describe("rodeo pkg", () => {
  const studio = studioHandle(46600);
  beforeAll(studio.spawn);
  afterAll(studio.close);

  const run = (opts: Parameters<typeof studio.ctx.editDom.runCode>[0]) => studio.ctx.editDom.runCode(opts);

  describe("smoke", () => smoke(run));
  describe("rodeo.fs", () => fs(run));
  describe("rodeo.io", () => io(run));
  describe("rodeo.process", () => processTests(run));
  describe("rodeo.roblox", () => roblox(run));
  describe("rodeo.capture", () => capture(run));
  describe("rodeo.images", () => images(run));
  describe("rodeo.meshes", () => meshes(run));
});
