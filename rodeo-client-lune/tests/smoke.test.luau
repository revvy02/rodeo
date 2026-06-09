-- Smoke test: spawn `rodeo serve`, connect a client, exercise a handful of
-- unary RPCs, shut down cleanly. Run with: `lune run rodeo-client-lune/tests/smoke.test.luau`.

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local rodeo = require("../src")

local PORT = 44873

local function die(msg: string)
	stdio.write(`SMOKE FAIL: {msg}\n`)
	process.exit(1)
end

-- 1. Start `rodeo serve --port PORT` in the background.
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

-- 2. Connect — blocks until the server is reachable (or throws on timeout).
local connectOk, connectResult = pcall(rodeo.connect, { port = PORT })

local function cleanup()
	if connectOk then
		pcall((connectResult :: any).close)
	end
	pcall(function()
		serve:kill()
	end)
end

if not connectOk then
	cleanup()
	die(`server never reported healthy: {connectResult}`)
end

local client = connectResult :: rodeo.RodeoClient
print("✓ connected")

local state = client.getState()
assert(type(state) == "table", "state should be a table")
local studios = state.studios or {}
print(`✓ getState returned {#studios} studio(s)`)

local backends = client.listBackends()
assert(type(backends) == "table", "backends should be a table")
print(`✓ listBackends returned {#backends} backend(s)`)

local procs = client.listProcesses()
assert(type(procs) == "table", "processes should be a table")
print(`✓ listProcesses returned {#procs} process(es)`)

cleanup()
print("✓ smoke test passed")
