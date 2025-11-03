local function mapEntries<K, V, K2, V2>(map: { [K]: V }, mapFn: (key: K, value: V) -> (K2?, V2?)): { [K2]: V2 }
    local result = {}

    for key, value in map do
        local newKey, newValue = mapFn(key, value)
        if newKey ~= nil and newValue ~= nil then
            result[newKey] = newValue
        end
    end

    return result
end

return mapEntries
