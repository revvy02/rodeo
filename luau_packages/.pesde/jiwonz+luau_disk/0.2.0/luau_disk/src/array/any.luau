local function any<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if predicate(element, index) then
            return true
        end
    end
    return false
end

return any
