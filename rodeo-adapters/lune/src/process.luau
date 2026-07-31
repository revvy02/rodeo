-- @lune/process shim — maps to rodeo's _G.__rodeo_procs APIs
local g = _G.__rodeo_procs[_G.__rodeo_eid]
local platform = g.process.platform()
-- lune's os values are "windows" | "macos" | "linux" — same strings the
-- host reports.
local isWindows = platform == "windows"
-- lune guarantees cwd ends with the platform separator.
local separator = if isWindows then "\\" else "/"
local cwdStr = g.process.cwd()
if cwdStr:sub(-1) ~= separator then
	cwdStr ..= separator
end
return {
	-- lune's args are read-only (writes must error mentioning read-only);
	-- freeze a clone so the shared @rodeo args table stays untouched.
	args = table.freeze(table.clone(g.process.args)),
	env = g.process.env,
	cwd = cwdStr,
	exit = g.process.exit,
	os = platform,
}
