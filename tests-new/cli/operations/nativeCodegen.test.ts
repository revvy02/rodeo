// --!native codegen works through the rodeo pipeline.
//
// Two runs of an identical numeric kernel on a run-mode server DOM — one
// with the --!native hotcomment, one without — must produce the same result,
// and the native one must be meaningfully faster. This guards two things at
// once: that Studio actually native-compiles rodeo-submitted source in the
// server VM, and that the submission pipeline (inline_shims, runner
// wrapping) keeps the hotcomment at the top of the chunk where Luau
// requires it — if anything strips or displaces it, the speedup vanishes
// and the ratio assertion fails.
//
// The kernel is scalar float arithmetic with typed locals and branches —
// the shape native codegen speeds up most (fastcall-heavy loops are already
// fast interpreted and would mask the difference). Sized so the interpreted
// run takes long enough (hundreds of ms) that the ratio is far outside
// scheduler noise.
import { describe, it, expect, beforeAll, afterAll } from "bun:test";
import { cliStudioHandle } from "../helpers.js";

const PORT = 46294;
const studio = cliStudioHandle(PORT);

beforeAll(async () => {
  await studio.spawn();
}, 180_000);

afterAll(async () => {
  await studio.close();
});

function kernelSource(native: boolean): string {
  const directives = native ? "--!native\n--!optimize 2\n" : "--!optimize 2\n";
  return (
    directives +
    `
local function kernel(n: number): number
	local a = 0.0
	local b = 1.0
	for i = 1, n do
		a += b * 0.5 + (i % 3)
		b = a * 0.25 - b
		if b > 1e6 then
			b -= 1e6
		end
		if a > 1e6 then
			a -= 1e6
		end
	end
	return a + b
end

-- Warmup pass so allocation/first-touch costs don't pollute the timing.
kernel(1000)

local t0 = os.clock()
local result = kernel(60_000_000)
local elapsed = os.clock() - t0
return { elapsed = elapsed, result = result }
`
  );
}

describe("--!native codegen (CLI)", () => {
  it(
    "native beats interpreted on a run-mode server kernel, same result",
    async () => {
      const plain = await studio.runFn({
        source: kernelSource(false),
        mode: "run",
        context: "server",
      });
      expect(plain.ok, plain.output).toBe(true);
      const plainReturn = plain.return as { elapsed: number; result: number };

      const native = await studio.runFn({
        source: kernelSource(true),
        mode: "run",
        context: "server",
      });
      expect(native.ok, native.output).toBe(true);
      const nativeReturn = native.return as { elapsed: number; result: number };

      // Same math either way — codegen must not change results.
      expect(nativeReturn.result).toBe(plainReturn.result);

      const ratio = plainReturn.elapsed / nativeReturn.elapsed;
      // Real native speedups on this kernel shape are several-fold; 1.5x is
      // the flake-safe floor that still proves codegen engaged (interpreted
      // vs interpreted jitters around 1.0x).
      expect(
        ratio,
        `interpreted ${plainReturn.elapsed.toFixed(3)}s vs native ${nativeReturn.elapsed.toFixed(3)}s — ` +
          `ratio ${ratio.toFixed(2)}x suggests --!native did not engage`,
      ).toBeGreaterThan(1.5);
    },
    300_000,
  );
});
