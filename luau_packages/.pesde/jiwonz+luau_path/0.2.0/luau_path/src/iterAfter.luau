local Component = require('./Component')

type Component = Component.Component

type ComponentIterator = { next: (self: ComponentIterator) -> Component? }
type Clone<T> = { clone: (T) -> T }

local function iterAfter<T>(
    iter: T & ComponentIterator & Clone<ComponentIterator>,
    prefix: T & ComponentIterator
): (T & ComponentIterator)?
    while true do
        local iterNext = iter:clone()
        local x = iterNext:next()
        local y = prefix:next()

        if x ~= nil and y ~= nil then
            if not x:equal(y) then
                return nil
            end
        elseif y == nil then
            return iter
        else
            return nil
        end
        iter = iterNext :: any
    end
end

return iterAfter
