local function range<T>(array: { T }, from: number, to: number?): { T }
    local length = #array
    if length == 0 then
        return array
    end
    local actualTo = if to == nil then length else to

    local normalizedFrom = if from < 0 then 1 + (from + length) else from
    local normalizedTo = if actualTo < 0 then 1 + (actualTo + length) else actualTo

    local result = {}

    if normalizedTo >= normalizedFrom then
        for i = math.max(normalizedFrom, 1), math.min(normalizedTo, length) do
            table.insert(result, array[i])
        end
    else
        for i = math.min(normalizedFrom, length), math.max(normalizedTo, 1), -1 do
            table.insert(result, array[i])
        end
    end

    return result
end

return range
