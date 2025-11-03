local function fromFn<T>(generator: (number) -> T?): { T }
    local array = {}

    local i = 1
    while true do
        local element = generator(i)
        if element == nil then
            break
        else
            i += 1
            table.insert(array, element)
        end
    end

    return array
end

return fromFn
