local function concat<T>(array: { T }, ...: { T }?): { T }
    local result = nil

    for i = 1, select('#', ...) do
        local concatWith = select(i, ...)

        if concatWith ~= nil and #concatWith > 0 then
            result = result or table.clone(array)

            for _, element in concatWith do
                table.insert(result, element)
            end
        end
    end

    return result or array
end

return concat
