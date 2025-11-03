local None = require('../None')

local function mapValues<K, V, W>(map: { [K]: V }, mapFn: (value: V, key: K) -> W?): { [K]: W }
    local result = {}

    for key, value in map do
        local newValue = mapFn(value, key)
        if newValue ~= nil and newValue ~= (None :: any) then
            result[key] = newValue
        end
    end

    return result
end

return mapValues
