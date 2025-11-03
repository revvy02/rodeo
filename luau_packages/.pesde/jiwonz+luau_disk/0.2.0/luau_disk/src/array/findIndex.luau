local function findIndex<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): number?
    if start == nil or start == 1 then
        for index, element in array do
            if predicate(element, index) then
                return index
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            if predicate(element, i) then
                return i
            end
        end
    end

    return nil
end

return findIndex
