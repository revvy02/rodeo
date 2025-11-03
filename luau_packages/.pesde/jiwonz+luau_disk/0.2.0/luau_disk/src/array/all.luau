local function all<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if not predicate(element, index) then
            return false
        end
    end
    return true
end

return all
