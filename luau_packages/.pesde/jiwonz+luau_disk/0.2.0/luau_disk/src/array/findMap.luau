local function findMap<T, U>(array: { T }, mapFn: (element: T, index: number) -> U?, start: number?): U?
    if start == nil or start == 1 then
        for index, element in array do
            local result = mapFn(element, index)
            if result ~= nil then
                return result
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            local result = mapFn(element, i)
            if result ~= nil then
                return result
            end
        end
    end

    return nil
end

return findMap
