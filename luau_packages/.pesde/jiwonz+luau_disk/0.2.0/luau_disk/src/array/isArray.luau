local function isArray(value: unknown): boolean
    if type(value) ~= 'table' then
        return false
    end

    local tableValue: { [any]: any } = value :: any

    if next(tableValue) == nil then
        -- an empty table is an empty array
        return true
    end

    local length = #tableValue

    if length == 0 then
        return false
    end

    local expectIndex = 0

    for key in tableValue do
        expectIndex += 1
        if type(key) ~= 'number' or key ~= expectIndex then
            return false
        end
    end

    return length == expectIndex
end

return isArray
