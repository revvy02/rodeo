-- @rodeo/process shim
local plugins, key = _G.__rodeo_plugins, script and script:GetAttribute("rodeoPlugin")
local ns = plugins and key and plugins[key]
local g = if ns then ns.procs[script:GetAttribute("rodeoExecutionId")] else _G.__rodeo_procs[_G.__rodeo_eid]
return g.process
