local reduce = require('./reduce')

local function zip<T>(array: { T }, ...: { T }): { { T } }
    local alternateWith = { ... }

    local minimumLength = reduce(alternateWith, function(minimum: number, value)
        return math.min(minimum, #value)
    end, #array)

    if minimumLength == 0 then
        return {}
    end

    local result = {}

    for i = 1, minimumLength do
        local entry = { array[i] }
        for _, otherArray in alternateWith do
            table.insert(entry, otherArray[i])
        end
        table.insert(result, entry)
    end

    return result
end

type zip1 = <A>({ A }) -> { { A } }
type zip2 = <A, B>({ A }, { B }) -> { { A | B } }
type zip3 = <A, B, C>({ A }, { B }, { C }) -> { { A | B | C } }
type zipAll = <T, U>({ T }, ...{ U }) -> { { T | U } }

return (zip :: any) :: zip1 & zip2 & zip3 & zipAll
