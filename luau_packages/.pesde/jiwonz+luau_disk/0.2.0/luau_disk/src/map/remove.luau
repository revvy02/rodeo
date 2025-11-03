local isEmpty = require('./isEmpty')

local function remove<K, V>(map: { [K]: V }, ...: K?)
    local removeLength = select('#', ...)

    if removeLength == 0 or isEmpty(map) then
        return map
    else
        local result = nil

        for i = 1, removeLength do
            local key: K = select(i, ...)

            if key ~= nil and map[key] ~= nil then
                result = result or table.clone(map)
                result[key] = nil
            end
        end

        return result or map
    end
end

return remove
