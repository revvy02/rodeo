local reduce = require('./reduce')

local function alternate<T, U>(array: { T }, ...: { U }): { any }
    local alternateWith = { ... }

    if #alternateWith == 0 then
        return array
    end

    local minimumLength = reduce(alternateWith, function(minimum: number, value)
        return math.min(minimum, #value)
    end, #array)

    if minimumLength == 0 then
        return {}
    end

    local result = {}

    for i = 1, minimumLength do
        table.insert(result, array[i])
        for _, otherArray in alternateWith do
            table.insert(result, otherArray[i] :: any)
        end
    end

    return result
end

type alternate1 = <A>({ A }) -> { A }
type alternate2 = <A, B>({ A }, { B }) -> { A | B }
type alternate3 = <A, B, C>({ A }, { B }, { C }) -> { A | B | C }
type alternateAll = <T, U, V...>({ T }, V...) -> { U }

return (alternate :: any) :: alternate1 & alternate2 & alternate3 & alternateAll
