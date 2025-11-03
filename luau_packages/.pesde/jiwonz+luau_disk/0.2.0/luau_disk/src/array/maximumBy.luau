local function maximumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.maximumBy when the array is empty')
        end
        initialValue = map(array[1])
    end

    local accumulator: number = initialValue :: number
    for _, element in array do
        accumulator = math.max(accumulator, map(element))
    end
    return accumulator
end

return maximumBy
