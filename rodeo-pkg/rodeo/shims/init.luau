-- @rodeo shim — returns the full rodeo API table from _G
local g = _G.__rodeo_procs[(script and script:GetAttribute("rodeoExecutionId")) or _G.__rodeo_eid]
return g
