--!strict
-- Run all transform benchmarks via rodeo-client-lune against an isolated
-- multiplayer-test server (no edit Studio in the background), then generate
-- diff flamegraphs vs the bulkmoveto baseline.

local fs = require("@lune/fs")
local process = require("@lune/process")
local task = require("@lune/task")

local rodeo = require("../../../rodeo-client-lune/src")

local DIR = ".rodeo/benchmarks/transforms"
local SCENARIOS = DIR .. "/scenarios"
local PROFILES = DIR .. "/results/profiles"
local DFGS = DIR .. "/results/dfgs"
local PORT = 44899

if fs.isDir(DIR .. "/results") then
	fs.removeDir(DIR .. "/results")
end
fs.writeDir(PROFILES)
fs.writeDir(DFGS)

local serve = process.create("rodeo", { "serve", "--port", tostring(PORT) })

-- Lune's process.create always pipes; drain stdout/stderr so the 64KB pipe
-- buffer doesn't fill and block serve.
task.spawn(function()
	while true do
		if serve.stdout:read() == nil then break end
	end
end)
task.spawn(function()
	while true do
		if serve.stderr:read() == nil then break end
	end
end)
local client = rodeo.connect({ port = PORT })
task.wait(1)
local backend = client.getLocalStudio()

local function profile(runCodeOpts: rodeo.RunCodeOpts)
	local server = backend.startMultiplayerTest({ profile = true, noHud = true })
	server.runCode(runCodeOpts)
	server.close()
end

-- bulkmoveto(baseline)
profile({
	file = SCENARIOS .. "/bulkmoveto.luau",
	target = "play:server",
	profile = PROFILES .. "/bulkmoveto",
})

-- bulkmoveto_raw_hack
profile({
	file = SCENARIOS .. "/bulkmoveto_raw_hack.luau",
	target = "play:server",
	profile = PROFILES .. "/bulkmoveto_hack",
})

-- attachment_cframe
profile({
	file = SCENARIOS .. "/attachment_cframe.luau",
	target = "play:server",
	profile = PROFILES .. "/attachment_cframe",
})

-- attachment_cframe_raw_hack
profile({
	file = SCENARIOS .. "/attachment_cframe_raw_hack.luau",
	target = "play:server",
	profile = PROFILES .. "/attachment_cframe_hack",
})

-- bone_transform
profile({
	file = SCENARIOS .. "/bone_transform.luau",
	target = "play:server:plugin",
	profile = PROFILES .. "/bone_transform",
})

-- bone_transform_raw_hack
profile({
	file = SCENARIOS .. "/bone_transform_raw_hack.luau",
	target = "play:server:plugin",
	profile = PROFILES .. "/bone_transform_hack",
})

-- motor6d_transform
profile({
	file = SCENARIOS .. "/motor6d_transform.luau",
	target = "play:server",
	profile = PROFILES .. "/motor6d_transform",
})

-- motor6d_transform_raw_hack
profile({
	file = SCENARIOS .. "/motor6d_transform_raw_hack.luau",
	target = "play:server",
	profile = PROFILES .. "/motor6d_transform_hack",
})

client.close()
serve:kill()

-- Diff flamegraphs vs bulkmoveto baseline
local baseline = PROFILES .. "/bulkmoveto"
local function dfg(name: string, dir: string)
	process.exec("rbx-microprofiler", {
		"diff-flamegraph",
		"-b",
		baseline,
		"-c",
		dir,
		"-o",
		DFGS .. "/bulkmoveto_vs_" .. name .. ".html",
	}, { stdio = "forward" })
end
dfg("bulkmoveto_raw_hack", PROFILES .. "/bulkmoveto_hack")
dfg("attachment_cframe", PROFILES .. "/attachment_cframe")
dfg("attachment_cframe_raw_hack", PROFILES .. "/attachment_cframe_hack")
dfg("bone_transform", PROFILES .. "/bone_transform")
dfg("bone_transform_raw_hack", PROFILES .. "/bone_transform_hack")
dfg("motor6d_transform", PROFILES .. "/motor6d_transform")
dfg("motor6d_transform_raw_hack", PROFILES .. "/motor6d_transform_hack")
