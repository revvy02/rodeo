local function values<K, V>(map: { [K]: V }): { V }
    local result = {}
    for _, value in map do
        table.insert(result, value)
    end
    return result
end

return values
