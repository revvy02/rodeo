-- End-to-end test of vm.runCode against a live Studio.
-- Run: `lune run rodeo-client-lune/tests/runcode.test.luau`.

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local rodeo = require("../src")

local PORT = 44874

local serve = process.create("rodeo", { "serve", "--port", tostring(PORT) })
-- Drain serve's pipes so its tracing logs don't deadlock on a full 64KB buffer.
local function drain(reader)
	while true do
		local chunk = reader:read()
		if chunk == nil then break end
	end
end
task.spawn(drain, serve.stdout)
task.spawn(drain, serve.stderr)

local client: rodeo.RodeoClient? = nil
local studio: rodeo.Studio? = nil

local function cleanup()
	if studio then
		pcall((studio :: any).close)
	end
	if client then
		pcall((client :: any).close)
	end
	pcall(function()
		serve:kill()
	end)
end

local function die(msg: string): never
	stdio.write(`RUNCODE FAIL: {msg}\n`)
	cleanup()
	process.exit(1)
	error("unreachable")
end

local function contains(haystack: string, needle: string): boolean
	return string.find(haystack, needle, 1, true) ~= nil
end

-- 1. Connect — blocks until serve is reachable, or throws on timeout.
local connectOk, connectResult = pcall(rodeo.connect, { port = PORT })
if not connectOk then
	die(`server never reported healthy: {connectResult}`)
end
client = connectResult
local c = connectResult :: rodeo.RodeoClient
print("✓ connected")

-- 2. Open Studio (background). This blocks until the edit VM connects.
local backend = c.getLocalStudio()
local ok, result = pcall(backend.open, { background = true })
if not ok then
	die(`studio.open failed: {result}`)
end
studio = result :: rodeo.Studio
print(`✓ studio opened (editVm: {studio.editVm.vmId})`)

-- Helper: run a source string and return (ok, result|errMsg).
local function tryRun(opts: rodeo.RunCodeOpts): (boolean, any)
	return pcall(studio.editVm.runCode, opts)
end

-- ── Case 1: print output is captured ──────────────────────────────────
do
	local ok, r = tryRun({ source = 'print("hello from lune")' })
	if not ok then
		die(`case 1 errored: {r}`)
	end
	local run = r :: rodeo.RunResult
	if not run.ok then
		die(`case 1: expected ok, got exitCode={run.exitCode}, output={run.output}`)
	end
	if not contains(run.output, "hello from lune") then
		die(`case 1: output missing greeting: {run.output}`)
	end
	if run.exitCode ~= 0 then
		die(`case 1: expected exitCode=0, got {run.exitCode}`)
	end
	print("✓ runCode: print output captured")
end

-- ── Case 2: return value via showReturn ───────────────────────────────
do
	local ok, r = tryRun({ source = "return 42", showReturn = true })
	if not ok then
		die(`case 2 errored: {r}`)
	end
	local run = r :: rodeo.RunResult
	if not run.ok then
		die(`case 2: expected ok, got exitCode={run.exitCode}, output={run.output}`)
	end
	if not contains(run.output, "42") then
		die(`case 2: output missing 42: {run.output}`)
	end
	print("✓ runCode: return value (showReturn)")
end

-- ── Case 3: error propagates as non-ok ────────────────────────────────
do
	local ok, r = tryRun({ source = "error('boom')" })
	if not ok then
		die(`case 3 errored: {r}`)
	end
	local run = r :: rodeo.RunResult
	if run.ok then
		die(`case 3: expected non-ok on error`)
	end
	if run.exitCode ~= 1 then
		die(`case 3: expected exitCode=1, got {run.exitCode}`)
	end
	print("✓ runCode: error as non-ok")
end

-- ── Case 4: multi-line source ─────────────────────────────────────────
do
	local ok, r = tryRun({ source = "local x = 1 + 2\nprint(x)" })
	if not ok then
		die(`case 4 errored: {r}`)
	end
	local run = r :: rodeo.RunResult
	if not run.ok then
		die(`case 4: expected ok, got output={run.output}`)
	end
	if not contains(run.output, "3") then
		die(`case 4: output missing 3: {run.output}`)
	end
	print("✓ runCode: multi-line")
end

cleanup()
print("✓ runcode test passed")
