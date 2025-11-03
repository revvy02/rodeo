local function sort<T>(array: { T }, comparator: ((T, T) -> boolean)?): { T }
    if #array <= 1 then
        return array
    end
    local result = table.clone(array)
    table.sort(result, comparator)
    return result
end

return sort
