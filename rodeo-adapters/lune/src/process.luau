-- @lune/process shim — maps to rodeo's _G.__rodeo_procs APIs
local g = _G.__rodeo_procs[_G.__rodeo_eid]
local cwdStr = g.process.cwd()
local isWindows = cwdStr:find("\\") ~= nil and cwdStr:find("/") == nil
return {
	args = g.process.args,
	env = g.process.env,
	cwd = cwdStr,
	exit = g.process.exit,
	os = if isWindows then "windows" else "macos",
}
