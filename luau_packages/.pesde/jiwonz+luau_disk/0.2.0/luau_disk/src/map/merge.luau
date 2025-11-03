local None = require('../None')

local function merge<T, U...>(...: U...): any
    local first = nil
    local firstIndex = nil
    local length = select('#', ...)

    for i = 1, length do
        local mergeMap = select(i, ...)

        if mergeMap ~= nil then
            firstIndex = i
            first = mergeMap
            break
        end
    end

    if first == nil then
        error('attempt to merge only nil values')
    end

    if firstIndex == length then
        return first
    end

    local result = nil

    for i = firstIndex + 1, length do
        local mergeMap = select(i, ...)

        if mergeMap ~= nil then
            if result == nil then
                result = table.clone(first)
                setmetatable(result, nil)
            end

            local metatable = getmetatable(mergeMap)

            if metatable ~= nil and type(metatable.__call) == 'function' then
                for key, value in pairs(mergeMap) do
                    if value == None then
                        result[key] = nil
                    else
                        result[key] = value
                    end
                end
            else
                for key, value in mergeMap do
                    if value == None then
                        result[key] = nil
                    else
                        result[key] = value
                    end
                end
            end
        end
    end

    return result or first
end

type merge1 = <A>(A) -> A
type merge2 = <A, B>(A, B) -> A & B
type merge3 = <A, B, C>(A, B, C) -> A & B & C
type merge4 = <A, B, C, D>(A, B, C, D) -> A & B & C & D
type merge5 = <A, B, C, D, E>(A, B, C, D, E) -> A & B & C & D & E
type mergeAll = <T, U, V...>(T, V...) -> U

return (merge :: any) :: merge1 & merge2 & merge3 & merge4 & merge5 & mergeAll
