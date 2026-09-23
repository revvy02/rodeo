import { describe, it, expect, afterAll } from "bun:test";
import { setupBackend } from "../helpers.js";
const ctx = setupBackend();
import type { Studio } from "../../../rodeo-client-ts/src/index.js";

const LOADMODULE_BASELINE_SCRIPT = `
local m = Instance.new("ModuleScript")
m.Name = "RodeoTestModule"
m.Source = "return 42"
m.Parent = game:GetService("ReplicatedStorage")

local ok, result = pcall(function()
  return debug.loadmodule(m)()
end)

m:Destroy()

if ok then
  return result
else
  return "LOADMODULE_UNAVAILABLE"
end
`;

const LOADMODULE_CACHE_SCRIPT = `
local m = Instance.new("ModuleScript")
m.Name = "RodeoCacheTestModule"
m.Source = 'return { value = "original" }'
m.Parent = game:GetService("ReplicatedStorage")

local t1 = require(m)
t1.value = "mutated"

local t2 = require(m)
local cachedIsMutated = (t2.value == "mutated")

local fresh = debug.loadmodule(m)()
local freshIsOriginal = (fresh.value == "original")

m:Destroy()

return "cached_mutated=" .. tostring(cachedIsMutated) .. ",fresh_original=" .. tostring(freshIsOriginal)
`;

describe("fflags", () => {
  it("debug.loadmodule is unavailable without fflag", async () => {
    const backend = await ctx.client.getLocalStudio();
    const noFflagStudio = await backend.open({ background: true });
    const result = await noFflagStudio.editDom.runCode({
      source: LOADMODULE_BASELINE_SCRIPT,
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("LOADMODULE_UNAVAILABLE");

    await noFflagStudio.close()
  });

  it("debug.loadmodule bypasses require cache with fflag", async () => {
    const backend = await ctx.client.getLocalStudio();
    const fflagStudio = await backend.open({
      fflags: ["EnableLoadModule=true"],
      background: true,
    });
    const result = await fflagStudio.editDom.runCode({
      source: LOADMODULE_CACHE_SCRIPT,
      showReturn: true,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("cached_mutated=true");
    expect(result.output).toContain("fresh_original=true");

    await fflagStudio.close()
  });
});
