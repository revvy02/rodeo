local Disk = require('../luau_packages/luau_disk')

local Array = Disk.Array

export type Rev<T> = {
    next: (self: Rev<T>) -> T?,
    collect: (self: Rev<T>) -> { T },
    rev: (self: Rev<T>) -> Rev<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev<T>) -> T?,

    clone: (self: Rev<T>) -> Rev<T>,
}

type DoubleEndedIterator<T> = {
    next: (self: DoubleEndedIterator<T>) -> T?,
    nextBack: (self: DoubleEndedIterator<T>) -> T?,

    clone: (self: DoubleEndedIterator<T>) -> DoubleEndedIterator<T>,
}

type Private<T> = {
    _iter: DoubleEndedIterator<T>,
}
type PrivateRev<T> = Rev<T> & Private<T>

type RevStatic = {
    new: <T>(iter: DoubleEndedIterator<T>) -> Rev<T>,

    next: <T>(self: Rev<T>) -> T?,
    collect: <T>(self: Rev<T>) -> { T },
    rev: <T>(self: Rev<T>) -> Rev<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev<T>) -> T?,

    clone: <T>(self: Rev<T>) -> Rev<T>,
}

local Rev: RevStatic = {} :: any
local RevMetatable = {
    __index = Rev,
    __iter = function<T>(self: PrivateRev<T>)
        local items = self:collect()
        return next, items
    end,
}

function Rev.new<T>(iter: DoubleEndedIterator<T>): Rev<T>
    local self: Private<T> = {
        _iter = iter,
    }

    return setmetatable(self, RevMetatable) :: any
end

function Rev:next<T>(): T?
    local self: PrivateRev<T> = self :: any

    return self._iter:nextBack()
end

function Rev:collect<T>(): { T }
    local self: PrivateRev<T> = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Rev:nextBack<T>(): T?
    local self: PrivateRev<T> = self :: any

    return self._iter:next()
end

function Rev:clone<T>(): Rev<T>
    local self: PrivateRev<T> = self :: any

    return Rev.new(self._iter:clone())
end

return Rev
