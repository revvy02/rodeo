local function pop<T>(array: { T }, count: number?): { T }
    local actualCount = count or 1

    if actualCount == 1 then
        local new = table.clone(array)
        table.remove(new)
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
                table.remove(new)
            end

            return new
        else
            local new = {}

            for i = 1, remaining do
                new[i] = array[i]
            end
            return new
        end
    end
end

return pop
