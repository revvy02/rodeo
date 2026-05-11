-- @lune/stdio shim — maps to rodeo's stream.write(io.stderr/stdout, ...)
local g = _G.__rodeo_procs[_G.__rodeo_eid]
return {
	ewrite = function(s: string)
		g.stream.write(g.io.stderr, s)
	end,
	write = function(s: string)
		g.stream.write(g.io.stdout, s)
	end,
}
