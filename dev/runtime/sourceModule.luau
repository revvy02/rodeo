--[[stylua: ignore start]] return function(input) --[[RODEO_UPVALUES]] local function __RODEO_SET_UPVALUE__(k, v) --[[RODEO_SET_UPVALUE]] end local function __RODEO_GET_UPVALUE__(k) --[[RODEO_GET_UPVALUE]] end return input(__RODEO_SET_UPVALUE__, __RODEO_GET_UPVALUE__), function(...) return xpcall(function(...) --[[SOURCE]]
end, function(err)
    return debug.traceback(err, 2)
end, ...) end end