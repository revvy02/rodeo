import { afterAll, beforeAll, describe, expect, it } from "bun:test";
import { existsSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { cliStudioHandle, runRodeo } from "../helpers.js";

const PORT = 46220;

function mkTmp(ext: string): string {
  return join(tmpdir(), `rodeo-dir-${randomUUID()}${ext}`);
}

function writeScript(directive: string, body: string): string {
  const path = mkTmp(".luau");
  writeFileSync(path, `${directive}\n${body}`);
  return path;
}

function rmIfExists(path: string): void {
  try { unlinkSync(path); } catch {}
}

describe("directives (CLI)", () => {
  const cli = cliStudioHandle(PORT);
  beforeAll(cli.spawn);
  afterAll(cli.close);

  // Regression for the originally-reported --return bug. The pre-refactor
  // directive applier was a hand-written match that silently dropped any
  // flag without an explicit arm — `--return` was one of those. The argv
  // splice makes directives flow through the same clap parse as CLI args,
  // so this Just Works.
  it("--return directive writes file", () => {
    const outPath = mkTmp(".luau");
    const script = writeScript(
      `-- @rodeo run --return ${outPath}`,
      `return { ok = true, n = 42 }`,
    );
    try {
      const r = runRodeo(["run", "--port", String(PORT), script]);
      expect(r.ok).toBe(true);
      expect(existsSync(outPath)).toBe(true);
      const content = readFileSync(outPath, "utf8");
      expect(content).toContain('["ok"] = true');
      expect(content).toContain('["n"] = 42');
    } finally {
      rmIfExists(script);
      rmIfExists(outPath);
    }
  });

  // Validates the structural-fix premise: a CLI flag that was never
  // enumerated in the old hand-written directive switch should work in a
  // directive *automatically* under the splice. If `--output` is ever
  // removed or repurposed, pick another previously-unmirrored flag
  // (--sourcemap, --logs, --no-hud, --place.universe, --verbose).
  it("auto-parity: --output directive routes prints to file", () => {
    const outPath = mkTmp(".txt");
    const script = writeScript(
      `-- @rodeo run --output ${outPath}`,
      `print("output_directive_ok") return nil`,
    );
    try {
      const r = runRodeo(["run", "--port", String(PORT), script]);
      expect(r.ok).toBe(true);
      expect(existsSync(outPath)).toBe(true);
      expect(readFileSync(outPath, "utf8")).toContain("output_directive_ok");
    } finally {
      rmIfExists(script);
      rmIfExists(outPath);
    }
  });

  // CLI overrides directive on conflict. Splice injects directive tokens
  // *before* user CLI args, so clap's last-arg-wins resolves to the CLI
  // value for scalar fields. Observable via RunService:IsRunning() —
  // true in run mode, false in edit mode.
  it("CLI --target overrides directive --target", () => {
    const script = writeScript(
      `-- @rodeo run --target edit:plugin --show-return`,
      `return game:GetService("RunService"):IsRunning()`,
    );
    try {
      const r = runRodeo([
        "run", "--port", String(PORT), script,
        "--target", "run:server",
      ]);
      expect(r.ok).toBe(true);
      expect(r.stdout + r.stderr).toContain("true");
    } finally {
      rmIfExists(script);
    }
  });

  // Sanity that --show-return directive (one of the few that *was* in the
  // old switch) still works post-refactor. Mirrors the coverage in
  // executionTests.ts:scriptFile but in the new dedicated home.
  it("--show-return directive prints return value", () => {
    const script = writeScript(
      `-- @rodeo run --show-return`,
      `return "show_return_directive_ok"`,
    );
    try {
      const r = runRodeo(["run", "--port", String(PORT), script]);
      expect(r.ok).toBe(true);
      expect(r.stdout + r.stderr).toContain("show_return_directive_ok");
    } finally {
      rmIfExists(script);
    }
  });
});
