local function partition<T>(array: { T }, predicate: (T, number) -> boolean): ({ T }, { T })
    local trueValues = {}
    local falseValues = {}
    for i, element in array do
        if predicate(element, i) then
            table.insert(trueValues, element)
        else
            table.insert(falseValues, element)
        end
    end
    return trueValues, falseValues
end

return partition
