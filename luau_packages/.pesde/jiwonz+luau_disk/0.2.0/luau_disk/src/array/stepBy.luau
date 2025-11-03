local function stepBy<T>(array: { T }, step: number): { T }
    local length = #array

    if step == 1 then
        return array
    elseif step == -1 then
        local newArray = table.clone(array)

        for i = 1, math.floor(length / 2) do
            local swapRight = length - i + 1

            newArray[i], newArray[swapRight] = newArray[swapRight], newArray[i]
        end

        return newArray
    elseif step > 1 then
        local result = {}

        for i = 1, length, step do
            table.insert(result, array[i])
        end

        return result
    elseif step < -1 then
        local result = {}

        for i = length, 1, step do
            table.insert(result, array[i])
        end

        return result
    else
        error(`invalid step value '{step}' passed to Array.stepBy`)
    end
end

return stepBy
