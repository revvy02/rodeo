local function sum(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += element
    end

    return result
end

return sum
