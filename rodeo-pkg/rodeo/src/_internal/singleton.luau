-- Internal: the rodeo singleton (metatable + _G.__rodeo_eid dispatch).
-- Imported by every public module file (fs.luau, io.luau, etc.) so the
-- per-execution dispatch is shared. Has no upward dependencies so the
-- module graph stays acyclic.
--
-- NOTE: this is the typedef-side singleton. The actual runtime shims in
-- rodeo-pkg/rodeo/shims/ read _G.__rodeo_procs directly and don't go through
-- this file at all — they're embedded into the plugin at build time.

local rodeo = {}

setmetatable(rodeo, {
	__index = function(_, key)
		-- Process-scoped lookup via _G.__rodeo_eid (set by runner)
		local eid = _G.__rodeo_eid
		if eid and _G.__rodeo_procs then
			local g = _G.__rodeo_procs[eid]
			if g then
				return g[key]
			end
		end
		-- Fallback for single-process mode
		local g = _G.__rodeo
		assert(g ~= nil, "rodeo APIs not available — are you running this outside of rodeo?")
		return g[key]
	end,
})

return rodeo
