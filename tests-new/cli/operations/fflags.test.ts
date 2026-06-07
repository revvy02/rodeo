import { describe, it, expect } from "bun:test";
import { existsSync, readdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { runRodeo } from "../helpers.js";

// Resolve the Studio ClientSettings dir the same way rodeo does (fflags.rs:
// `client_settings_dir`): it sits beside the Studio executable. macOS keeps it
// inside the .app bundle; Windows puts it under
// %LOCALAPPDATA%\Roblox\Versions\<hash>\ — the version dir that actually
// contains RobloxStudioBeta.exe. Hardcoding the macOS path made the restore
// assertions check a non-existent dir on Windows (trivial pass).
function resolveClientSettingsDir(): string {
  if (process.platform === "darwin") {
    return "/Applications/RobloxStudio.app/Contents/MacOS/ClientSettings";
  }
  if (process.platform === "win32") {
    const versions = join(process.env.LOCALAPPDATA ?? "", "Roblox", "Versions");
    let exeDir: string | undefined;
    try {
      for (const name of readdirSync(versions)) {
        if (existsSync(join(versions, name, "RobloxStudioBeta.exe"))) exeDir = join(versions, name);
      }
    } catch {}
    if (!exeDir) throw new Error("RobloxStudioBeta.exe not found under %LOCALAPPDATA%\\Roblox\\Versions");
    return join(exeDir, "ClientSettings");
  }
  throw new Error(`unsupported platform for fflags test: ${process.platform}`);
}

const CLIENT_SETTINGS_DIR = resolveClientSettingsDir();
const SETTINGS_FILE = join(CLIENT_SETTINGS_DIR, "ClientAppSettings.json");
const LOCK_PREFIX = "ClientAppSettings.json.lock.";

function findLockFiles(): string[] {
  if (!existsSync(CLIENT_SETTINGS_DIR)) return [];
  return readdirSync(CLIENT_SETTINGS_DIR).filter((n) => n.startsWith(LOCK_PREFIX));
}

type Snapshot = { exists: boolean; content?: string };

function snapshotSettings(): Snapshot {
  if (existsSync(SETTINGS_FILE)) {
    return { exists: true, content: readFileSync(SETTINGS_FILE, "utf8") };
  }
  return { exists: false };
}

function assertRestored(snapshot: Snapshot): void {
  expect(findLockFiles().length).toBe(0);
  if (snapshot.exists) {
    expect(existsSync(SETTINGS_FILE)).toBe(true);
    expect(readFileSync(SETTINGS_FILE, "utf8")).toBe(snapshot.content!);
  }
}

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

describe("fflags (CLI)", () => {
  it("debug.loadmodule is unavailable without fflag", () => {
    const snapshot = snapshotSettings();
    const result = runRodeo([
      "run", "--place", "--port", "46230",
      "--source", LOADMODULE_BASELINE_SCRIPT,
      "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("LOADMODULE_UNAVAILABLE");
    assertRestored(snapshot);
  });

  it("debug.loadmodule bypasses require cache", () => {
    const snapshot = snapshotSettings();
    const result = runRodeo([
      "run", "--place", "--port", "46232",
      "--fflag.override", "EnableLoadModule=true",
      "--source", LOADMODULE_CACHE_SCRIPT,
      "--show-return",
    ]);
    expect(result.ok).toBe(true);
    expect(result.stdout + result.stderr).toContain("cached_mutated=true");
    expect(result.stdout + result.stderr).toContain("fresh_original=true");
    assertRestored(snapshot);
  });

  it("--fflag.file applies flags", () => {
    const snapshot = snapshotSettings();
    const tmpFile = "rodeo-test-fflags-tmp.json";
    writeFileSync(tmpFile, JSON.stringify({ FFlagEnableLoadModule: true }));
    try {
      const result = runRodeo([
        "run", "--place", "--port", "46234",
        "--fflag.file", tmpFile,
        "--source", LOADMODULE_CACHE_SCRIPT,
        "--show-return",
      ]);
      expect(result.ok).toBe(true);
      expect(result.stdout + result.stderr).toContain("cached_mutated=true");
      expect(result.stdout + result.stderr).toContain("fresh_original=true");
      assertRestored(snapshot);
    } finally {
      if (existsSync(tmpFile)) unlinkSync(tmpFile);
    }
  });

  it("flags are restored after exit", () => {
    const snapshot = snapshotSettings();
    const result = runRodeo([
      "run", "--place", "--port", "46236",
      "--fflag.override", "EnableLoadModule=true",
      "--source", "return nil",
    ]);
    expect(result.ok).toBe(true);
    assertRestored(snapshot);
  });
});
