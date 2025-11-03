local function reverse<T>(array: { T }): { T }
    local length = #array

    if length < 2 then
        return array
    end

    local newArray = table.clone(array)

    for i = 1, math.floor(length / 2) do
        local swapRight = length - i + 1

        newArray[i], newArray[swapRight] = newArray[swapRight], newArray[i]
    end

    return newArray
end

return reverse
