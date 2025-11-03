local function deduplicate<T>(array: { T }): { T }
    if #array == 0 then
        return array
    end

    local removeIndexes = {}

    local seenSet = {}

    for index, element in array do
        if seenSet[element] == nil then
            seenSet[element] = true
        else
            table.insert(removeIndexes, index)
        end
    end

    local totalIndexes = #removeIndexes
    if totalIndexes == 0 then
        return array
    else
        local result = table.clone(array)
        for i = totalIndexes, 1, -1 do
            table.remove(result, removeIndexes[i])
        end
        return result
    end
end

return deduplicate
