local function fromTryFn<T>(generator: (number) -> T?): { T }
    local array = {}

    local i = 1
    while true do
        local success, element = pcall(generator, i)
        if success == false or element == nil then
            break
        else
            i += 1
            table.insert(array, element)
        end
    end

    return array
end

return fromTryFn
