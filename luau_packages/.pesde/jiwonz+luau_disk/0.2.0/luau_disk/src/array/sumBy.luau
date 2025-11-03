local function sumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += map(element)
    end

    return result
end

return sumBy
