local function find<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): T?
    if start == nil or start == 1 then
        for index, element in array do
            if predicate(element, index) then
                return element
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            if predicate(element, i) then
                return element
            end
        end
    end

    return nil
end

return find
