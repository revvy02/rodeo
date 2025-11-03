local function keys<K, V>(map: { [K]: V }): { K }
    local result = {}
    for key in map do
        table.insert(result, key)
    end
    return result
end

return keys
