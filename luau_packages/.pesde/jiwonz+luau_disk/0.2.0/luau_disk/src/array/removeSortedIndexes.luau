local function removeSortedIndexes<T>(array: { T }, indexes: { number }): { T }
    local removeLength = #indexes
    local arrayLenth = #array

    if removeLength == 0 or arrayLenth == 0 then
        return array
    end

    local startFrom = nil
    for i = removeLength, 1, -1 do
        local index = indexes[i]
        if index <= arrayLenth then
            startFrom = index
            break
        end
    end

    if startFrom == nil then
        return array
    else
        local cloned = table.clone(array)
        local length = arrayLenth

        local previous = nil
        for i = startFrom, 1, -1 do
            local index = indexes[i]
            if index ~= previous and index <= length then
                length -= 1
                table.remove(cloned, index)
                previous = index
            end
        end

        return cloned
    end
end

return removeSortedIndexes
