local function count<K, V>(map: { [K]: V }): number
    local length = 0
    for _ in map do
        length += 1
    end
    return length
end

return count
