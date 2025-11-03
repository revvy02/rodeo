local function push<T>(array: { T }, ...: T?): { T }
    local newArray = table.clone(array)

    for i = 1, select('#', ...) do
        local element = select(i, ...)
        if element ~= nil then
            table.insert(newArray, element)
        end
    end

    return newArray
end

return push
