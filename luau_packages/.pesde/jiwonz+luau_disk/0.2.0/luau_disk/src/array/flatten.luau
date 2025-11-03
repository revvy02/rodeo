local isArray = require('./isArray')

local function flatten<T>(array: { T | { T } }, depth: number?): { T }
    local actualDepth = if depth == nil then math.huge else depth
    if actualDepth == 0 then
        return array :: { T }
    end

    local new = {}

    for _, element in array do
        if isArray(element) then
            local iter: { T } = if actualDepth > 1
                then flatten(element :: { T })
                else element :: { T }
            for _, innerElement in iter do
                table.insert(new, innerElement)
            end
        else
            table.insert(new, element :: T)
        end
    end

    return new
end

return flatten
