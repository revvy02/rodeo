local map = require('./map')

type KeyElement<K, V> = { key: K, element: V }

local function sortByKey<T, Comparable>(array: { T }, key: (T) -> Comparable): { T }
    if #array <= 1 then
        return array
    end
    local result: { KeyElement<Comparable, T> } = map(array, function(element)
        return {
            key = key(element),
            element = element,
        }
    end)

    table.sort(result, function(a: any, b: any)
        return a.key < b.key
    end)

    for index, element in result do
        result[index] = element.element :: any
    end

    return result :: any
end

return sortByKey
