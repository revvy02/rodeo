local WEAK_KEYS_METATABLE = { __mode = 'k' }

local function WeakMap<K, V>(default: { [K]: V }?): { [K]: V }
    local value = default or {}
    return setmetatable(value :: any, WEAK_KEYS_METATABLE) :: any
end

return WeakMap
