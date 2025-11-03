local isArray = require('./isArray')

local function flatMap<T, U>(array: { T }, mapFn: (T, number) -> nil | U | { U }): { U }
    local new = {}
    for i, element in array do
        local value = mapFn(element, i)
        if value ~= nil then
            if isArray(value) then
                for _, innerElement in value :: { U } do
                    table.insert(new, innerElement)
                end
            else
                table.insert(new, value :: U)
            end
        end
    end
    return new
end

return flatMap
