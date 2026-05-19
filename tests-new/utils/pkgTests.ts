// Shared @rodeo/* API test cases — port of tests/utils/pkgTests.luau.
// Each module is a function taking a `run(opts)` closure that executes against
// some VM. No case names or script sources are modified from the lute version.

import { it, expect } from "bun:test";
import type { RunCodeOpts, RunResult } from "../../rodeo-client-ts/src/run.js";

export type RunFn = (opts: RunCodeOpts) => Promise<RunResult>;

// Remove a directory and everything under it, ignoring errors (for idempotent fixtures)
function rmrf(path: string): void {
  Bun.spawnSync(["rm", "-rf", path], { stdio: ["ignore", "inherit", "inherit"] });
}

// ── smoke (1 test) ────────────────────────────────────────────────────────

export function smoke(run: RunFn): void {
  it("all rodeo modules exist", async () => {
    const result = await run({
      showReturn: true,
      source: `return {
          fs = require("@rodeo/fs") ~= nil,
          io = require("@rodeo/io") ~= nil,
          process = require("@rodeo/process") ~= nil,
          stream = require("@rodeo/stream") ~= nil,
      }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"fs":true');
    expect(result.output).toContain('"io":true');
    expect(result.output).toContain('"process":true');
    expect(result.output).toContain('"stream":true');
  });
}

// ── fs (8 tests) ──────────────────────────────────────────────────────────

export function fs(run: RunFn): void {
  it("fs: open + write + read round-trip", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-fs.txt", "w")
        stream.write(f, "hello fs")
        stream.close(f)
        local f2 = fs.open("rodeo-test-fs.txt", "r")
        local data = stream.read(f2)
        stream.close(f2)
        fs.remove("rodeo-test-fs.txt")
        return data`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("hello fs");
  });

  it("fs: overwrite replaces content", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-overwrite.txt", "w")
        stream.write(f, "first")
        stream.close(f)
        local f2 = fs.open("rodeo-test-overwrite.txt", "w")
        stream.write(f2, "second")
        stream.close(f2)
        local f3 = fs.open("rodeo-test-overwrite.txt", "r")
        local data = stream.read(f3)
        stream.close(f3)
        fs.remove("rodeo-test-overwrite.txt")
        return data`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("second");
  });

  it("fs: exists and type", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-exists.txt", "w")
        stream.write(f, "x")
        stream.close(f)
        local exists = fs.exists("rodeo-test-exists.txt")
        local ftype = fs.type("rodeo-test-exists.txt")
        local missing = fs.exists("rodeo-nonexistent-xyz.txt")
        fs.remove("rodeo-test-exists.txt")
        return { exists = exists, type = ftype, missing = missing }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"exists":true');
    expect(result.output).toContain('"type":"file"');
    expect(result.output).toContain('"missing":false');
  });

  it("fs: mkdir + listdir + rmdir", async () => {
    rmrf("rodeo-test-dir");
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        fs.mkdir("rodeo-test-dir")
        local exists = fs.exists("rodeo-test-dir")
        local dtype = fs.type("rodeo-test-dir")
        local f = fs.open("rodeo-test-dir/a.txt", "w")
        stream.write(f, "a")
        stream.close(f)
        local entries = fs.listdir("rodeo-test-dir")
        fs.remove("rodeo-test-dir/a.txt")
        fs.rmdir("rodeo-test-dir")
        return { exists = exists, type = dtype, entryCount = #entries }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"exists":true');
    expect(result.output).toContain('"type":"dir"');
    expect(result.output).toContain('"entryCount":1');
  });

  it("fs: remove deletes file", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-rm.txt", "w")
        stream.write(f, "x")
        stream.close(f)
        fs.remove("rodeo-test-rm.txt")
        return fs.exists("rodeo-test-rm.txt")`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("false");
  });

  it("fs: copy duplicates file", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-copy-src.txt", "w")
        stream.write(f, "copy me")
        stream.close(f)
        fs.copy("rodeo-test-copy-src.txt", "rodeo-test-copy-dst.txt")
        local f2 = fs.open("rodeo-test-copy-dst.txt", "r")
        local data = stream.read(f2)
        stream.close(f2)
        local srcExists = fs.exists("rodeo-test-copy-src.txt")
        fs.remove("rodeo-test-copy-src.txt")
        fs.remove("rodeo-test-copy-dst.txt")
        return { data = data, srcExists = srcExists }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("copy me");
    expect(result.output).toContain('"srcExists":true');
  });

  it("fs: stat returns metadata", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-stat.txt", "w")
        stream.write(f, "meta")
        stream.close(f)
        local stat = fs.stat("rodeo-test-stat.txt")
        fs.remove("rodeo-test-stat.txt")
        return { hasType = stat.type ~= nil, statType = stat.type }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"hasType":true');
    expect(result.output).toContain('"statType":"file"');
  });

  it("fs: read large file (2MB JSON)", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("tests-new/fixtures/pkg/giant_file.json", "r")
        local content = stream.read(f)
        stream.close(f)
        local len = #content
        local parsed = game:GetService("HttpService"):JSONDecode(content)
        local hasElevation = parsed.elevation ~= nil
        local width = parsed.elevation and parsed.elevation.width or 0
        return { len = len, hasElevation = hasElevation, width = width }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"hasElevation":true');
    expect(result.output).toContain('"width":454');
  });

  it("stream: readBytes/writeBytes round-trip non-UTF-8 bytes", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local input = buffer.create(6)
        buffer.writeu8(input, 0, 0x00); buffer.writeu8(input, 1, 0xFF)
        buffer.writeu8(input, 2, 0xC0); buffer.writeu8(input, 3, 0xC1)
        buffer.writeu8(input, 4, 0xFE); buffer.writeu8(input, 5, 0xFF)

        local w = fs.open("rodeo-test-bytes.bin", "w")
        stream.writeBytes(w, input)
        stream.close(w)

        local r = fs.open("rodeo-test-bytes.bin", "r")
        local out = stream.readBytes(r)
        stream.close(r)
        fs.remove("rodeo-test-bytes.bin")

        return {
          len = buffer.len(out),
          b0 = buffer.readu8(out, 0), b1 = buffer.readu8(out, 1),
          b2 = buffer.readu8(out, 2), b3 = buffer.readu8(out, 3),
          b4 = buffer.readu8(out, 4), b5 = buffer.readu8(out, 5),
        }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"len":6');
    expect(result.output).toContain('"b0":0');
    expect(result.output).toContain('"b1":255');
    expect(result.output).toContain('"b2":192');
    expect(result.output).toContain('"b3":193');
    expect(result.output).toContain('"b4":254');
    expect(result.output).toContain('"b5":255');
  });
}

// ── io (3 tests) ──────────────────────────────────────────────────────────

export function io(run: RunFn): void {
  it("io: stdout write is captured", async () => {
    const result = await run({
      source: `local io = require("@rodeo/io")
        local stream = require("@rodeo/stream")
        stream.write(io.stdout, "hello from io\\n")`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("hello from io");
  });

  it("io: stderr write is captured", async () => {
    // Lute asserts `result.err`. TS client merges stdout+stderr into `output`.
    const result = await run({
      source: `local io = require("@rodeo/io")
        local stream = require("@rodeo/stream")
        stream.write(io.stderr, "stderr msg\\n")`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("stderr msg");
  });

  it("io: file round-trip via fs + stream", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local f = fs.open("rodeo-test-io.txt", "w")
        stream.write(f, "line one\\n")
        stream.write(f, "line two\\n")
        stream.close(f)
        local f2 = fs.open("rodeo-test-io.txt", "r")
        local data = stream.read(f2)
        stream.close(f2)
        fs.remove("rodeo-test-io.txt")
        return data`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("line one");
    expect(result.output).toContain("line two");
  });
}

// ── process (10 tests) ────────────────────────────────────────────────────

export function process(run: RunFn): void {
  it("process: cwd, homedir, execpath are functions", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        return {
            cwdIsFunc = type(p.cwd) == "function",
            cwdNonEmpty = #p.cwd() > 0,
            homedirIsFunc = type(p.homedir) == "function",
            homedirNonEmpty = #p.homedir() > 0,
            execpathIsFunc = type(p.execpath) == "function",
        }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"cwdIsFunc":true');
    expect(result.output).toContain('"cwdNonEmpty":true');
    expect(result.output).toContain('"homedirIsFunc":true');
    expect(result.output).toContain('"homedirNonEmpty":true');
    expect(result.output).toContain('"execpathIsFunc":true');
  });

  it("process: args is a table", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        return type(p.args) == "table"`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("process: env is readable and read-only", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local homeExists = p.env.HOME ~= nil
        local writeBlocked = not pcall(function() p.env.TEST = "x" end)
        return { homeExists = homeExists, writeBlocked = writeBlocked }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"homeExists":true');
    expect(result.output).toContain('"writeBlocked":true');
  });

  it("process: run executes command", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local r = p.run({ "echo", "hello" })
        return { ok = r.ok, exitcode = r.exitcode, hasHello = string.find(r.out, "hello") ~= nil }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"ok":true');
    expect(result.output).toContain('"exitcode":0');
    expect(result.output).toContain('"hasHello":true');
  });

  it("process: run returns failure for bad command", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local r = p.run({ "false" })
        return { ok = r.ok }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"ok":false');
  });

  it("process: system runs shell command", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local r = p.system("echo $HOME")
        return { ok = r.ok, noLiteral = string.find(r.out, "$HOME") == nil }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"ok":true');
    expect(result.output).toContain('"noLiteral":true');
  });

  it("process: create + stream read", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local stream = require("@rodeo/stream")
        local child = p.create({ "echo", "piped output" }, { stdio = "piped" })
        local output = stream.read(child.stdout)
        return string.find(output, "piped output") ~= nil`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("process: create + multiple stream reads via stdin/stdout", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local stream = require("@rodeo/stream")
        local child = p.create({ "cat" }, { stdio = "piped" })
        stream.write(child.stdin, "first\\n")
        local r1 = stream.read(child.stdout)
        stream.write(child.stdin, "second\\n")
        local r2 = stream.read(child.stdout)
        stream.close(child.stdin)
        return { r1 = r1, r2 = r2, bothRead = r1 ~= nil and r2 ~= nil }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"bothRead":true');
    expect(result.output).toContain("first");
    expect(result.output).toContain("second");
  });

  it("process: create + stream write to stdin", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local stream = require("@rodeo/stream")
        local child = p.create({ "cat" }, { stdio = "piped" })
        stream.write(child.stdin, "hello from stdin\\n")
        stream.close(child.stdin)
        local output = stream.read(child.stdout)
        return string.find(output, "hello from stdin") ~= nil`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("process: create + kill", async () => {
    const result = await run({
      showReturn: true,
      source: `local p = require("@rodeo/process")
        local sleeper = p.create({ "sleep", "10" }, { stdio = "piped" })
        p.kill(sleeper)
        local status = p.run(sleeper)
        return status.ok == false`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });
}

// ── roblox (3 tests, plugin-only) ─────────────────────────────────────────

export function roblox(run: RunFn): void {
  it("roblox: import can parent instances to workspace", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local instances = roblox.import("./tests-new/fixtures/pkg/test-folder.rbxm")
        instances[1].Parent = workspace
        local found = workspace:FindFirstChild(instances[1].Name) ~= nil
        instances[1]:Destroy()
        return found`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain("true");
  });

  it("roblox: import returns instances from rbxm", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local instances = roblox.import("./tests-new/fixtures/pkg/test-folder.rbxm")
        return { count = #instances, class = instances[1].ClassName }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"count":1');
    expect(result.output).toContain('"class":"Folder"');
  });

  it("roblox: export + import round-trips instance class+name", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local fs = require("@rodeo/fs")
        local folder = Instance.new("Folder")
        folder.Name = "RodeoTestExport"
        local part = Instance.new("Part")
        part.Name = "ChildPart"
        part.Parent = folder

        local outPath = "rodeo-test-export.rbxm"
        roblox.export(outPath, { folder })

        local imported = roblox.import(outPath)
        fs.remove(outPath)

        return {
          count = #imported,
          name = imported[1].Name,
          class = imported[1].ClassName,
          childName = imported[1]:FindFirstChild("ChildPart") and imported[1].ChildPart.Name or "missing",
          childClass = imported[1]:FindFirstChild("ChildPart") and imported[1].ChildPart.ClassName or "missing",
        }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"count":1');
    expect(result.output).toContain('"name":"RodeoTestExport"');
    expect(result.output).toContain('"class":"Folder"');
    expect(result.output).toContain('"childName":"ChildPart"');
    expect(result.output).toContain('"childClass":"Part"');
  });

  it("roblox: import nonexistent file errors", async () => {
    const result = await run({
      source: `local roblox = require("@rodeo/roblox")
        roblox.import("./nonexistent-file-12345.rbxm")`,
    });
    expect(result.ok).toBe(false);
  });

  it("roblox: import returns instances from rbxmx", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local instances = roblox.import("./tests-new/fixtures/pkg/test-folder.rbxmx")
        return { count = #instances, class = instances[1].ClassName }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"count":1');
    expect(result.output).toContain('"class":"Folder"');
  });

  it("roblox: export with .rbxmx extension writes XML format", async () => {
    const result = await run({
      showReturn: true,
      source: `local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        local roblox = require("@rodeo/roblox")

        local folder = Instance.new("Folder")
        folder.Name = "XmlExportTest"

        local path = "rodeo-test-xml-export.rbxmx"
        roblox.export(path, { folder })

        local r = fs.open(path, "r")
        local content = stream.read(r)
        stream.close(r)
        fs.remove(path)

        local head = content:sub(1, 7)
        -- rbx-xml emits "<roblox version=..." (text); binary .rbxm starts with
        -- "<roblox!\\x89\\xff..." (non-text after the literal "<roblox").
        return { head = head, isXml = head == "<roblox" and content:sub(8, 8) ~= "!" }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"isXml":true');
  });

  it("roblox: export to .rbxmx + import round-trips structure", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local fs = require("@rodeo/fs")

        local folder = Instance.new("Folder")
        folder.Name = "XmlRoundtrip"
        local part = Instance.new("Part")
        part.Name = "XmlChild"
        part.Parent = folder

        local path = "rodeo-test-xml-roundtrip.rbxmx"
        roblox.export(path, { folder })

        local imported = roblox.import(path)
        fs.remove(path)

        return {
          count = #imported,
          name = imported[1].Name,
          class = imported[1].ClassName,
          childName = imported[1]:FindFirstChild("XmlChild") and imported[1].XmlChild.Name or "missing",
          childClass = imported[1]:FindFirstChild("XmlChild") and imported[1].XmlChild.ClassName or "missing",
        }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"count":1');
    expect(result.output).toContain('"name":"XmlRoundtrip"');
    expect(result.output).toContain('"class":"Folder"');
    expect(result.output).toContain('"childName":"XmlChild"');
    expect(result.output).toContain('"childClass":"Part"');
  });

  it("roblox: export creates nested parent directories", async () => {
    const result = await run({
      showReturn: true,
      source: `local roblox = require("@rodeo/roblox")
        local fs = require("@rodeo/fs")

        local dir = "rodeo-test-nested-" .. tostring(math.random(1, 1e9))
        local path = dir .. "/sub/leaf/snapshot.rbxm"

        local function cleanup()
            if fs.exists(path) then fs.remove(path) end
            if fs.exists(dir .. "/sub/leaf") then fs.rmdir(dir .. "/sub/leaf") end
            if fs.exists(dir .. "/sub") then fs.rmdir(dir .. "/sub") end
            if fs.exists(dir) then fs.rmdir(dir) end
        end

        -- Defensive: clear leftover state from a prior crashed run.
        cleanup()

        local folder = Instance.new("Folder")
        folder.Name = "NestedDirsTest"
        roblox.export(path, { folder })

        local existed = fs.exists(path)

        cleanup()

        return { existed = existed }`,
    });
    expect(result.ok).toBe(true);
    expect(result.output).toContain('"existed":true');
  });
}
