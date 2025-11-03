local function invert<K, V>(map: { [K]: V }): { [V]: K }
    if next(map) == nil then
        return map :: any
    end

    local result = {}
    for key, value in map do
        result[value] = key
    end
    return result
end

return invert
