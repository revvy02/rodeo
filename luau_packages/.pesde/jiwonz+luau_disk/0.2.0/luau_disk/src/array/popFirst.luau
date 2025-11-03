local function popFirst<T>(array: { T }, count: number?): { T }
    local actualCount = count or 1

    if actualCount == 1 then
        local new = table.clone(array)
        table.remove(new, 1)
        return new
    elseif actualCount == 0 then
        return array
    else
        local length = #array

        local remaining = length - actualCount

        if remaining <= 0 then
            return {}
        elseif remaining > actualCount then
            local new = table.clone(array)

            for _ = 1, actualCount do
                table.remove(new, 1)
            end

            return new
        else
            local new = {}

            for i = 1 + actualCount, length do
                table.insert(new, array[i])
            end

            return new
        end
    end
end

return popFirst
