local None = table.freeze(setmetatable({}, {
    __index = function()
        error('attempt to index on None symbol')
    end,
    __tostring = function()
        return '<None>'
    end,
}))

return None
