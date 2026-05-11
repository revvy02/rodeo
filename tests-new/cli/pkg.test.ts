import { describe, beforeAll, afterAll } from "bun:test";
import { smoke, fs, io, process as processTests, roblox } from "../utils/pkgTests.js";
import { cliStudioHandle } from "./helpers.js";

describe("rodeo pkg (CLI)", () => {
  const cli = cliStudioHandle(46100);
  beforeAll(cli.spawn);
  afterAll(cli.close);

  describe("smoke", () => smoke(cli.runFn));
  describe("rodeo.fs", () => fs(cli.runFn));
  describe("rodeo.io", () => io(cli.runFn));
  describe("rodeo.process", () => processTests(cli.runFn));
  describe("roblox.load", () => roblox(cli.runFn));
});
