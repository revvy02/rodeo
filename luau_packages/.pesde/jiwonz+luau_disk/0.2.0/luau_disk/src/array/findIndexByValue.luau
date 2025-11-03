local function findIndexByValue<T>(array: { T }, element: T, start: number?): number?
    return table.find(array, element, start)
end

return findIndexByValue
