local function average(array: { number }): number?
    local length = #array
    if length == 0 then
        return nil
    end

    local result = 0

    for _, element in array do
        result += element
    end

    return result / length
end

return average
