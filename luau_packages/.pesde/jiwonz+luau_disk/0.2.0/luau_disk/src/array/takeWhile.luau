local function takeWhile<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): { T }
    local arrayLength = #array

    if arrayLength == 0 then
        return array
    end

    local bound = arrayLength + 1
    local actualStart = if start == nil then 1 else start
    if actualStart == 1 then
        for index, element in array do
            if not predicate(element, index) then
                bound = index
                break
            end
        end
    else
        local length = #array
        for i = actualStart, length do
            local element = array[i]
            if not predicate(element, i) then
                bound = i
                break
            end
        end
    end

    if actualStart == bound then
        return {}
    elseif actualStart == 1 and bound > arrayLength then
        return array
    end

    local toInsert = bound - actualStart

    if actualStart == 1 and toInsert < arrayLength / 2 then
        local result = table.clone(array)

        for _ = 1, arrayLength - bound do
            table.remove(result)
        end

        return result
    else
        local result = {}

        for i = actualStart, bound - 1 do
            table.insert(result, array[i])
        end

        return result
    end
end

return takeWhile
