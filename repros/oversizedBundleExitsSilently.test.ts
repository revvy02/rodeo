// Repro (issue #9): a file entrypoint whose transitive bundle exceeds the
// run-submission payload limit exits 2 with EMPTY stdout/stderr — no rodeo
// diagnostic, nothing in Studio, --verbose adds nothing.
//
// The bundled source rides the client->master RunStream as a single message;
// an oversized one blows the master's receive cap, which drops the stream on
// receipt. Client-side, the stream loop's `_ => break` arm swallows the
// transport error (no Disconnect event exists — the transport itself died),
// and run_piped fabricates an exit-2 RunResult with empty output. The
// sender-side relay guards don't apply: they cover runtime rpc responses,
// not the initial submission.
//
// The fixture generates a ~20MB module tree on the fly (pseudo-random string
// literals so nothing compresses or dedups) plus a control entrypoint whose
// bundle is small, proving the pipeline itself works.
//
// Expected behavior: the oversized run fails BEFORE dispatch with a message
// naming the bundle size and the applicable limit (or, minimally, any
// transport failure is reported on stderr) — never a bare silent exit 2.
import { test, expect, afterAll } from "bun:test";
import { mkdirSync, rmSync, writeFileSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir, "..");
const RODEO = join(ROOT, "bin", "rodeo");
const PORT = 47410;
const FIXTURE_DIR = "/tmp/rodeo-oversized-bundle-repro";

const procs: Bun.Subprocess[] = [];

function cleanup() {
  for (const p of procs) {
    try { p.kill(9); } catch {}
  }
  Bun.spawnSync(["pkill", "-f", `__master --port ${PORT}`]);
  Bun.spawnSync(["pkill", "-f", `__studio-backend --port ${PORT + 1}`]);
  Bun.spawnSync(["pkill", "-f", `${ROOT}/.rodeo/.temp/rodeo-`]);
  try { rmSync(FIXTURE_DIR, { recursive: true, force: true }); } catch {}
}

afterAll(cleanup);

// Deterministic pseudo-random printable ASCII so the bundled source cannot
// shrink below the payload limit through literal dedup or compression. The
// alphabet (48..90: digits, punctuation, uppercase) deliberately excludes
// `"` and `\` so the output is always a valid Luau string literal.
function chunkOfJunk(seedStart: number, bytes: number): string {
  let state = 0x6d2b79f5 ^ seedStart;
  const chars: string[] = [];
  for (let i = 0; i < bytes; i++) {
    state ^= state << 13; state >>>= 0;
    state ^= state >> 17;
    state ^= state << 5; state >>>= 0;
    chars.push(String.fromCharCode(48 + (state % 43)));
  }
  return chars.join("");
}

function writeFixtures(moduleCount: number, bytesPerModule: number) {
  rmSync(FIXTURE_DIR, { recursive: true, force: true });
  mkdirSync(join(FIXTURE_DIR, "fixtures"), { recursive: true });
  // Bundling a file script resolves requires through luau configuration;
  // outside a project a .luaurc must exist next to the entrypoint. An
  // explicit index file (not init.luau) sidesteps the issue #6
  // directory-require limitation.
  writeFileSync(join(FIXTURE_DIR, ".luaurc"), "{}\n");
  const indexLines: string[] = ["return {"];
  for (let i = 0; i < moduleCount; i++) {
    writeFileSync(
      join(FIXTURE_DIR, "fixtures", `data${i}.luau`),
      `return "${chunkOfJunk(i, bytesPerModule)}"\n`,
    );
    indexLines.push(`\trequire("./data${i}"),`);
  }
  indexLines.push("}");
  writeFileSync(join(FIXTURE_DIR, "fixtures", "index.luau"), indexLines.join("\n") + "\n");
  writeFileSync(
    join(FIXTURE_DIR, "entry.luau"),
    `local fixtures = require("./fixtures/index")\nprint("fixtures loaded", #fixtures)\nreturn #fixtures\n`,
  );
  writeFileSync(
    join(FIXTURE_DIR, "control.luau"),
    `local one = require("./fixtures/data0")\nprint("control loaded", #one)\nreturn true\n`,
  );
}

async function runRodeo(args: string[], timeoutMs: number) {
  const proc = Bun.spawn([RODEO, ...args], { stdout: "pipe", stderr: "pipe" });
  procs.push(proc);
  const stdoutPromise = new Response(proc.stdout as ReadableStream).text();
  const stderrPromise = new Response(proc.stderr as ReadableStream).text();
  const result = await Promise.race([
    proc.exited.then((code) => ({ exited: true, code })),
    Bun.sleep(timeoutMs).then(() => ({ exited: false, code: -1 })),
  ]);
  if (!result.exited) {
    proc.kill(9);
    await proc.exited.catch(() => {});
  }
  const [stdout, stderr] = await Promise.all([
    stdoutPromise.catch(() => ""),
    stderrPromise.catch(() => ""),
  ]);
  return { ...result, stdout, stderr };
}

test("oversized bundle fails with a diagnostic, not a silent exit 2", async () => {
  cleanup();
  // 24 x 1MB modules ≈ 24MB of bundled source — over the 16MiB envelope.
  writeFixtures(24, 1_000_000);

  // Persistent serve: an implicit (run-spawned) serve exits with its run,
  // and the oversized run must hit a live master to exercise the transport.
  const serve = Bun.spawn([RODEO, "serve", "--port", String(PORT)], {
    stdout: "ignore",
    stderr: "ignore",
  });
  procs.push(serve);
  for (let i = 0; i < 60; i++) {
    const probe = Bun.spawnSync([RODEO, "state", "--port", String(PORT)]);
    if (probe.exitCode === 0) break;
    await Bun.sleep(1000);
  }

  // Control below the limit: same fixture tree, one module — must run.
  const control = await runRodeo(
    ["run", `${FIXTURE_DIR}/control.luau`, "--place", "--detach", "--port", String(PORT)],
    180_000,
  );
  expect(control.code, `${control.stdout}\n${control.stderr}`).toBe(0);
  expect(control.stdout).toContain("control loaded");

  // Oversized bundle against the same live serve/Studio.
  const big = await runRodeo(
    ["run", `${FIXTURE_DIR}/entry.luau`, "--port", String(PORT)],
    120_000,
  );

  expect(big.exited, "oversized run hung").toBe(true);
  // It must fail...
  expect(big.code).not.toBe(0);
  // ...but never silently: stderr names the size problem.
  expect(
    big.stderr.length,
    `exit ${big.code} with empty stderr — the silent failure from issue #9`,
  ).toBeGreaterThan(0);
  expect(big.stderr).toMatch(/limit|size|large|exceeds/i);
}, 330_000);
