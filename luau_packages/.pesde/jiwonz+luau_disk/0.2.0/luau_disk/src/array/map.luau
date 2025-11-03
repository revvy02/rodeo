local function map<T, U>(array: { T }, mapFn: (T, number) -> U?): { U }
    local new = {}
    for i, element in array do
        local value = mapFn(element, i)
        if value ~= nil then
            table.insert(new, value)
        end
    end
    return new
end

return map
