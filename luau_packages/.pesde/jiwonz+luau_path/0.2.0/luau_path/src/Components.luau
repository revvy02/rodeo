local Disk = require('../luau_packages/luau_disk')

local Component = require('./Component')
local Prefix = require('./Prefix')
local Rev = require('./Rev')
local sysPath = require('./sys/path')

local isSepByte = sysPath.isSepByte
local isVerbatimSep = sysPath.isVerbatimSep

type Component = Component.Component
type Prefix = Prefix.Prefix
type Rev<T> = Rev.Rev<T>

local Array = Disk.Array

type char = string

export type Components = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix?,

    prefixLen: (self: Components) -> number,
    prefixVerbatim: (self: Components) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components) -> number,
    -- is the iteration complete?
    finished: (self: Components) -> boolean,
    isSepByte: (self: Components, b: char) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components) -> string,
    hasRoot: (self: Components) -> boolean,
    includeCurDir: (self: Components) -> boolean,
    parseSingleComponent: (self: Components, comp: string) -> Component?,
    parseNextComponent: (self: Components) -> (number, Component?),
    parseNextComponentBack: (self: Components) -> (number, Component?),
    trimLeft: (self: Components) -> (),
    trimRight: (self: Components) -> (),

    -- Iterator
    next: (self: Components) -> Component?,
    collect: (self: Components) -> { Component },
    rev: (self: Components) -> Rev<Component>,
    -- DoubleEndedIterator
    nextBack: (self: Components) -> Component?,

    -- Clone
    clone: (self: Components) -> Components,
    equal: (self: Components, other: Components) -> boolean,
}

type IterComponents = (items: { Component }, index: number?) -> (number?, Component)

type State = 'Prefix' | 'StartDir' | 'Body' | 'Done'

local function getStateValue(state: State)
    if state == 'Done' then
        return 3
    elseif state == 'StartDir' then
        return 1
    elseif state == 'Prefix' then
        return 0
    else
        return 2
    end
end

type Private = {
    -- The path left to parse components from
    _path: string,

    -- true if path *physically* has a root separator; for most Windows
    -- prefixes, it may have a "logical" root separator for the purposes of
    -- normalization, e.g., \\server\share == \\server\share\.
    _hasPhysicalRoot: boolean,

    -- The iterator is double-ended, and these two states keep track of what has
    -- been produced from either end
    _front: State,
    _back: State,
}
type PrivateComponents = Components & Private

type ComponentsStatic = Components & Private & {
    new: (path: string, prefix: Prefix?, hasPhysicalRoot: boolean) -> Components,
    is: (value: unknown) -> boolean,
}

local Components: ComponentsStatic = {} :: any
local ComponentsMetatable = {
    __index = Components,
    __iter = function(self: PrivateComponents)
        local items = self:collect()
        return next, items
    end,
}

function Components.new(path: string, prefix: Prefix?, hasPhysicalRoot: boolean): Components
    local self: Private = {
        _path = path,
        prefix = prefix,
        _hasPhysicalRoot = hasPhysicalRoot,
        _front = 'Prefix',
        _back = 'Body',
    }

    return setmetatable(self, ComponentsMetatable) :: any
end

function Components.is(value: unknown): boolean
    return type(value) == 'table' and getmetatable(value :: any) == ComponentsMetatable
end

function Components:prefixLen(): number
    local self: PrivateComponents = self :: any

    local prefix = self.prefix
    return if prefix then prefix:len() else 0
end

function Components:prefixVerbatim(): boolean
    local self: PrivateComponents = self :: any

    local prefix = self.prefix
    return if prefix then prefix:isVerbatim() else false
end

-- how much of the prefix is left from the point of view of iteration?
function Components:prefixRemaining(): number
    local self: PrivateComponents = self :: any

    local front = self._front
    return if front == 'Prefix' then self:prefixLen() else 0
end

-- Given the iteration so far, how much of the pre-State::Body path is left?
function Components:lenBeforeBody(): number
    local self: PrivateComponents = self :: any

    local front: State = self._front
    local isBeforeStartDir = getStateValue(front) <= getStateValue('StartDir')
    local root = if isBeforeStartDir and self._hasPhysicalRoot then 1 else 0
    local curDir = if isBeforeStartDir and self:includeCurDir() then 1 else 0

    return self:prefixRemaining() + root + curDir
end

-- is the iteration complete?
function Components:finished(): boolean
    local self: PrivateComponents = self :: any

    local front: State = self._front
    local back: State = self._back
    return front == 'Done' or back == 'Done' or getStateValue(front) > getStateValue(back)
end

function Components:isSepByte(b: char): boolean
    local self: PrivateComponents = self :: any

    return if self:prefixVerbatim() then isVerbatimSep(b) else isSepByte(b)
end

function Components:asPathString(): string
    local self: PrivateComponents = self :: any

    local comps: PrivateComponents = self:clone() :: any
    if comps._front == 'Body' then
        comps:trimLeft()
    end
    if comps._back == 'Body' then
        comps:trimRight()
    end
    return comps._path
end

-- Is the *original* path rooted?
function Components:hasRoot(): boolean
    local self: PrivateComponents = self :: any

    if self._hasPhysicalRoot then
        return true
    end
    local prefix = self.prefix
    if prefix and prefix:hasImplicitRoot() then
        return true
    end
    return false
end

-- Should the normalized path include a leading . ?
function Components:includeCurDir(): boolean
    local self: PrivateComponents = self :: any

    if self:hasRoot() then
        return false
    end

    local index = self:prefixRemaining() + 1
    local first = string.sub(self._path, index, index)
    local second = string.sub(self._path, index + 1, index + 1)

    local firstIsDot = first == '.'

    -- check if second is "" instead of nil
    return if firstIsDot and second == ''
        then true
        elseif firstIsDot and second ~= '' then self:isSepByte(second)
        else false
end

-- parse a given byte sequence following the OsStr encoding into the
-- corresponding path component
function Components:parseSingleComponent(comp: string): Component?
    local self: PrivateComponents = self :: any

    if comp == '.' then
        if self:prefixVerbatim() then
            return Component.curDir()
        else
            -- . components are normalized away, except at
            -- the beginning of a path, which is treated
            -- separately via `includeCurDir`
            return nil
        end
    elseif comp == '..' then
        return Component.parentDir()
    elseif comp == '' then
        return nil
    else
        return Component.normal(comp)
    end
end

-- parse a component from the left, saying how many bytes to consume to
-- remove the component
function Components:parseNextComponent(): (number, Component?)
    local self: PrivateComponents = self :: any

    local path = self._path
    local extra = 0
    local comp = path

    for i = 1, #path do
        if self:isSepByte(string.sub(path, i, i)) then
            extra = 1
            comp = string.sub(path, 1, i - 1)
            break
        end
    end

    return #comp + extra, self:parseSingleComponent(comp)
end

-- parse a component from the right, saying how many bytes to consume to
-- remove the component
function Components:parseNextComponentBack(): (number, Component?)
    local self: PrivateComponents = self :: any

    local start = self:lenBeforeBody() + 1
    local path = self._path

    local extra = 0
    local comp = string.sub(path, start)

    for i = #path, start, -1 do
        if self:isSepByte(string.sub(path, i, i)) then
            extra = 1
            comp = string.sub(path, i + 1)
            break
        end
    end

    return #comp + extra, self:parseSingleComponent(comp)
end

-- trim away repeated separators (i.e., empty components) on the left
function Components:trimLeft()
    local self: PrivateComponents = self :: any

    while self._path ~= '' do
        local size, comp = self:parseNextComponent()
        if comp ~= nil then
            return
        else
            self._path = string.sub(self._path, size + 1)
        end
    end
end

-- trim away repeated separators (i.e., empty components) on the right
function Components:trimRight()
    local self: PrivateComponents = self :: any

    while #self._path > self:lenBeforeBody() do
        local size, comp = self:parseNextComponentBack()
        if comp ~= nil then
            return
        else
            self._path = string.sub(self._path, 1, #self._path - size)
        end
    end
end

function Components:next(): Component?
    local self: PrivateComponents = self :: any

    while not self:finished() do
        local front: State = self._front

        if front == 'Prefix' then
            self._front = 'StartDir'
            local prefixLen = self:prefixLen()
            if prefixLen > 0 then
                local raw = string.sub(self._path, 1, prefixLen)
                self._path = string.sub(self._path, prefixLen + 1)

                return Component.prefix(raw, self.prefix :: Prefix)
            end
        elseif front == 'StartDir' then
            self._front = 'Body'

            if self._hasPhysicalRoot then
                self._path = string.sub(self._path, 2)
                return Component.rootDir()
            elseif self.prefix ~= nil then
                if self.prefix:hasImplicitRoot() and not self.prefix:isVerbatim() then
                    return Component.rootDir()
                end
            elseif self:includeCurDir() then
                self._path = string.sub(self._path, 2)
                return Component.curDir()
            end
        elseif front == 'Body' then
            if self._path ~= '' then
                local size, comp = self:parseNextComponent()
                self._path = string.sub(self._path, size + 1)

                if comp ~= nil then
                    return comp
                end
            else
                self._front = 'Done'
            end
        else
            error('unreachable')
        end
    end

    return nil
end

function Components:collect(): { Component }
    local self: PrivateComponents = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Components:rev(): Rev<Component>
    local self: PrivateComponents = self :: any

    return Rev.new(self:clone())
end

function Components:nextBack(): Component?
    local self: PrivateComponents = self :: any

    while not self:finished() do
        local back: State = self._back

        if back == 'Body' then
            if #self._path > self:lenBeforeBody() then
                local size, comp = self:parseNextComponentBack()
                self._path = string.sub(self._path, 1, #self._path - size)

                if comp ~= nil then
                    return comp
                end
            else
                self._back = 'StartDir'
            end
        elseif back == 'StartDir' then
            self._back = 'Prefix'
            if self._hasPhysicalRoot then
                self._path = string.sub(self._path, 1, #self._path - 1)
                return Component.rootDir()
            elseif self.prefix ~= nil then
                local p = self.prefix
                if p:hasImplicitRoot() and not p:isVerbatim() then
                    return Component.rootDir()
                end
            elseif self:includeCurDir() then
                self._path = string.sub(self._path, 1, #self._path - 1)
                return Component.curDir()
            end
        elseif back == 'Prefix' then
            self._back = 'Done'

            if self:prefixLen() > 0 then
                return Component.prefix(self._path, self.prefix :: Prefix)
            end
        else
            error('unreachable')
        end
    end

    return nil
end

function Components:clone(): Components
    local self: PrivateComponents = self :: any

    local newSelf: PrivateComponents = table.clone(self) :: any

    if newSelf.prefix then
        newSelf.prefix = newSelf.prefix:clone()
    end

    return setmetatable(newSelf, ComponentsMetatable) :: any
end

function Components:equal(other: Components): boolean
    local self: PrivateComponents = self :: any
    local other: PrivateComponents = other :: any

    -- Fast path for exact matches, e.g. for hashmap lookups.
    -- Don't explicitly compare the prefix or has_physical_root fields since they'll
    -- either be covered by the `path` buffer or are only relevant for `prefix_verbatim()`.
    if
        #self._path == #other._path
        and self._front == other._front
        and self._back == 'Body'
        and other._back == 'Body'
        and self:prefixVerbatim() == other:prefixVerbatim()
    then
        -- possible future improvement: this could bail out earlier if there were a
        -- reverse memcmp/bcmp comparing back to front
        if self._path == other._path then
            return true
        end
    end

    -- compare back to front since absolute paths often share long prefixes
    local selfClone = self:clone()
    local otherClone = other:clone()

    local selfComponent = selfClone:nextBack()
    local otherComponent = otherClone:nextBack()

    while selfComponent and otherComponent do
        if not selfComponent:equal(otherComponent) then
            return false
        end
        selfComponent = selfClone:nextBack()
        otherComponent = otherClone:nextBack()
    end

    return selfComponent == nil and otherComponent == nil
end

return Components
