local function minimum(array: { number }, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.minimum when the array is empty')
        end
        initialValue = array[1]
    end

    local accumulator = initialValue :: number
    for _, element in array do
        accumulator = math.min(accumulator, element)
    end
    return accumulator
end

return minimum
