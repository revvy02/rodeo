local function deduplicateByKey<T, Comparable>(array: { T }, key: (T) -> Comparable): { T }
    local removeIndexes = {}

    local seenSet = {}

    for index, element in array do
        local elementKey = key(element)
        if seenSet[elementKey] == nil then
            seenSet[elementKey] = true
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

return deduplicateByKey
