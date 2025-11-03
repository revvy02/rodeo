local function filter<T>(array: { T }, predicate: (T, number) -> boolean): { T }
    local new = {}
    for i, element in array do
        if predicate(element, i) then
            table.insert(new, element)
        end
    end
    return new
end

return filter
