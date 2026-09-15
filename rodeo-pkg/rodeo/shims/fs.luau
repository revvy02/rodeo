-- @rodeo/fs shim
local g = _G.__rodeo_procs[(script and script:GetAttribute("rodeoExecutionId")) or _G.__rodeo_eid]
return g.fs
