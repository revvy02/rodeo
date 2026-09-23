import { describe, it, expect } from "bun:test";
import { existsSync, mkdirSync, readFileSync, rmSync, unlinkSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { runRodeo } from "../cli/helpers.js";

// Port of tests/cli/setup.test.luau. Pure CLI tests — no background Studio.

describe("rodeo setup", () => {
  it("writes typedef files to ~/.rodeo/typedefs/{version}", () => {
    const r = runRodeo(["setup"]);
    expect(r.ok).toBe(true);
    expect(r.stderr).toContain("Wrote type definitions");

    const match = r.stderr.match(/typedefs\/([^/\n]+)/);
    expect(match).not.toBeNull();
    const version = match![1];

    const typedefs = join(homedir(), ".rodeo", "typedefs", version);
    expect(existsSync(join(typedefs, "init.luau"))).toBe(true);
    expect(existsSync(join(typedefs, "fs.luau"))).toBe(true);
    expect(existsSync(join(typedefs, "io.luau"))).toBe(true);
    expect(existsSync(join(typedefs, "process.luau"))).toBe(true);
    expect(existsSync(join(typedefs, "stream.luau"))).toBe(true);
  });

  it("creates .rodeo/.luaurc with rodeo alias", () => {
    if (existsSync(".rodeo/.luaurc")) unlinkSync(".rodeo/.luaurc");

    const r = runRodeo(["setup"]);
    expect(r.ok).toBe(true);
    expect(r.stderr).toContain(".rodeo/.luaurc");

    expect(existsSync(".rodeo/.luaurc")).toBe(true);
    const rc = JSON.parse(readFileSync(".rodeo/.luaurc", "utf8"));
    expect(rc.aliases).not.toBeUndefined();
    expect(rc.aliases.rodeo).not.toBeUndefined();
    expect(rc.aliases.rodeo).toContain("~/.rodeo/typedefs/");
  });

  it("preserves existing .luaurc aliases", () => {
    if (!existsSync(".rodeo")) mkdirSync(".rodeo", { recursive: true });
    writeFileSync(
      ".rodeo/.luaurc",
      JSON.stringify({ aliases: { custom: "./some/path" } }, null, 2),
    );

    const r = runRodeo(["setup"]);
    expect(r.ok).toBe(true);

    const rc = JSON.parse(readFileSync(".rodeo/.luaurc", "utf8"));
    expect(rc.aliases.custom).toBe("./some/path");
    expect(rc.aliases.rodeo).not.toBeUndefined();

    unlinkSync(".rodeo/.luaurc");
  });

  it("can run script with require(@rodeo) after setup", () => {
    runRodeo(["setup"]);

    // Bundle only works with file paths — write a temp script.
    const scriptPath = ".rodeo-test-require-rodeo.luau";
    writeFileSync(scriptPath, 'local rodeo = require("@rodeo")\nreturn type(rodeo)');

    const r = runRodeo([
      "run", "--place", "--port", "46000",
      scriptPath, "--show-return",
    ]);

    try { unlinkSync(scriptPath); } catch {}

    expect(r.ok).toBe(true);
    expect(r.stdout + r.stderr).toContain("table");
  });
});
