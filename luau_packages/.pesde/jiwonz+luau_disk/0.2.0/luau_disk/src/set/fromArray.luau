local type = require('./type')

type Set<T> = type.Set<T>

local function fromArray<T>(array: { T }): Set<T>
    local set: Set<T> = {}
    for _, element in array do
        set[element] = true
    end
    return set
end

return fromArray
