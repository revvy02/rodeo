local function product(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 1 else initialValue

    for _, element in array do
        result *= element
    end

    return result
end

return product
