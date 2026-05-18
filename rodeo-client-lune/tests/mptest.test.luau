-- Smoke test for backend.startMultiplayerTest — validates the Luau wire path
-- and the architectural property that MP test servers do NOT require an open
-- edit Studio.
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
local mpServer: rodeo.MultiplayerTestServer? = nil

local function cleanup()
	if mpServer then
		pcall((mpServer :: any).close)
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

-- 2. Start MP server WITHOUT calling backend.open() first — that's the whole point.
local backend = c.getLocalStudio()
local ok, result = pcall(backend.startMultiplayerTest, {})
if not ok then
	die(`backend.startMultiplayerTest failed: {result}`)
end
mpServer = result :: rodeo.MultiplayerTestServer
print(`✓ mp server started (vmId: {mpServer.vmId})`)

-- 3. Run a trivial script on the server VM (the server handle IS the Vm).
local runOk, runResult = pcall(mpServer.runCode, { source = "return 1 + 1", showReturn = true })
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
