local function contains<T>(array: { T }, element: T): boolean
    for _, value in array do
        if value == element then
            return true
        end
    end
    return false
end

return contains
