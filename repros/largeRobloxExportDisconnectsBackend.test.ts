// Repro: roblox.export sends the entire serialized model through one
// RobloxExportRequest. A sufficiently large model disconnects the Studio
// backend instead of completing the export or returning an actionable,
// export-scoped error.
//
// This fixture creates its payload inside a blank Studio so it does not depend
// on a particular place or checked-in binary asset. The StringValues contain
// deterministic pseudo-random printable ASCII, which prevents Roblox's binary
// serializer from shrinking the model below the backend relay limit. Keeping
// this near 8 MiB also avoids the separate `table overflow` failure in Rodeo's
// current whole-buffer base64 encoder.
//
// Observed with Rodeo v1.2.0-rc.8:
//   rodeo: run disconnected: backend disconnected while the run was active
//   (run aborted)
//
// Expected behavior: roblox.export either streams/chunks the model and writes
// it successfully, or fails promptly with an actionable size/resource error
// without disconnecting the Studio backend.
import { test, expect, afterAll } from "bun:test";
import { existsSync, rmSync } from "fs";
import { join } from "path";

const ROOT = join(import.meta.dir, "..");
const RODEO = join(ROOT, "bin", "rodeo");
const PORT = 47342;
const CONTROL_OUTPUT = "/tmp/rodeo-large-export-control.rbxm";
const OUTPUT = "/tmp/rodeo-large-export-repro.rbxm";

const procs: Bun.Subprocess[] = [];

function cleanup() {
  for (const p of procs) {
    try { p.kill(9); } catch {}
  }
  Bun.spawnSync(["pkill", "-f", `__master --port ${PORT}`]);
  Bun.spawnSync(["pkill", "-f", `__studio-backend --port ${PORT + 1}`]);
  Bun.spawnSync(["pkill", "-f", `${ROOT}/.rodeo/.temp/rodeo-`]);
  try { rmSync(CONTROL_OUTPUT, { force: true }); } catch {}
  try { rmSync(OUTPUT, { force: true }); } catch {}
}

afterAll(cleanup);

test("large roblox.export does not disconnect the Studio backend", async () => {
  cleanup();

  const source = `
local roblox = require("@rodeo/roblox")

local CONTROL_COUNT = 1500
local VALUE_COUNT = 4000
local BYTES_PER_VALUE = 2048
local WORDS_PER_VALUE = BYTES_PER_VALUE / 4
local root = Instance.new("Folder")
root.Name = "LargeExportRepro"

-- xorshift32 gives deterministic, poorly-compressible data. Each generated
-- byte is mapped into printable ASCII so this only exercises normal Roblox
-- StringValue serialization, not invalid-UTF-8 handling.
local state = 0x6D2B79F5
local function nextWord()
	state = bit32.bxor(state, bit32.lshift(state, 13))
	state = bit32.bxor(state, bit32.rshift(state, 17))
	state = bit32.bxor(state, bit32.lshift(state, 5))

	local a = 32 + bit32.band(state, 63)
	local b = 32 + bit32.band(bit32.rshift(state, 6), 63)
	local c = 32 + bit32.band(bit32.rshift(state, 12), 63)
	local d = 32 + bit32.band(bit32.rshift(state, 18), 63)
	return bit32.bor(a, bit32.lshift(b, 8), bit32.lshift(c, 16), bit32.lshift(d, 24))
end

local function appendValues(targetCount)
	for index = #root:GetChildren() + 1, targetCount do
		local payload = buffer.create(BYTES_PER_VALUE)
		for wordIndex = 0, WORDS_PER_VALUE - 1 do
			buffer.writeu32(payload, wordIndex * 4, nextWord())
		end

		local value = Instance.new("StringValue")
		value.Name = string.format("Payload_%05d", index)
		value.Value = buffer.tostring(payload)
		value.Parent = root
	end
end

-- Control: the same export path succeeds below the 4 MiB relay limit.
appendValues(CONTROL_COUNT)
roblox.export("${CONTROL_OUTPUT}", { root })
print("control export completed")

-- Repro: extending the same model to ~8 MiB disconnects the backend.
appendValues(VALUE_COUNT)
print(string.format(
	"exporting %d instances with %.1f MiB of pseudo-random string data",
	VALUE_COUNT,
	(VALUE_COUNT * BYTES_PER_VALUE) / (1024 * 1024)
))

roblox.export("${OUTPUT}", { root })
print("large export completed")
return true
`.trim();

  const proc = Bun.spawn(
    [
      RODEO,
      "run",
      "--port",
      String(PORT),
      "--place",
      "--source",
      source,
    ],
    { stdout: "pipe", stderr: "pipe" },
  );
  procs.push(proc);

  const stdoutPromise = new Response(proc.stdout as ReadableStream).text();
  const stderrPromise = new Response(proc.stderr as ReadableStream).text();
  const result = await Promise.race([
    proc.exited.then((code) => ({ exited: true, code })),
    Bun.sleep(240_000).then(() => ({ exited: false, code: -1 })),
  ]);
  if (!result.exited) {
    proc.kill(9);
    await proc.exited.catch(() => {});
  }
  const [stdout, stderr] = await Promise.all([
    stdoutPromise.catch(() => ""),
    stderrPromise.catch(() => ""),
  ]);

  expect(result.exited).toBe(true);
  expect(stdout).toContain("control export completed");
  expect(existsSync(CONTROL_OUTPUT)).toBe(true);
  expect(stderr).not.toContain("backend disconnected while the run was active");
  expect(result.code, `${stdout}\n${stderr}`).toBe(0);
  expect(existsSync(OUTPUT)).toBe(true);
}, 270_000);
