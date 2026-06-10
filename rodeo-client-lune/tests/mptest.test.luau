-- Smoke test for studio.startMultiplayerTest — validates the Luau wire path.
-- The multiplayer API now requires an OPEN EDIT STUDIO: the session runs
-- ExecuteMultiplayerTestAsync inside a real Studio, so this test only fully
-- passes against a live Studio; its structure validates the wire path.
-- Run: `lune run rodeo-client-lune/tests/mptest.test.luau`.

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local rodeo = require("../src")

local PORT = 44875

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
local mp: rodeo.MultiplayerTestServer? = nil

local function cleanup()
	if mp then
		pcall(function()
			(mp :: any).close()
		end)
	end
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
	stdio.write(`MPTEST FAIL: {msg}\n`)
	cleanup()
	process.exit(1)
	error("unreachable")
end

-- 1. Connect — blocks until serve is reachable, or throws on timeout.
local connectOk, connectResult = pcall(rodeo.connect, { port = PORT })
if not connectOk then
	die(`server never reported healthy: {connectResult}`)
end
client = connectResult
local c = connectResult :: rodeo.RodeoClient
print("✓ connected")

-- 2. Open an edit Studio — the MP API now requires one.
local backend = c.getLocalStudio()
local openOk, openResult = pcall(backend.open, {})
if not openOk then
	die(`backend.open failed: {openResult}`)
end
studio = openResult :: rodeo.Studio
local s = openResult :: rodeo.Studio
print("✓ edit studio opened")

-- 3. Start a multiplayer test (server only; clients join via connectClient).
local startOk, startResult = pcall(s.startMultiplayerTest)
if not startOk then
	die(`studio.startMultiplayerTest failed: {startResult}`)
end
mp = startResult :: rodeo.MultiplayerTestServer
print(`✓ mp started (server vmId: {mp.vmId})`)

-- 4. Run a trivial script on the server (an ordinary Vm).
local runOk, runResult = pcall(mp.runCode, { source = "return 1 + 1", showReturn = true })
if not runOk then
	die(`runCode errored: {runResult}`)
end
local run = runResult :: rodeo.RunResult
if not run.ok then
	die(`run failed: exitCode={run.exitCode}, output={run.output}`)
end
if not string.find(run.output, "2", 1, true) then
	die(`expected "2" in output, got: {run.output}`)
end
print("✓ server.runCode executed on MP server")

cleanup()
print("✓ mptest test passed")
