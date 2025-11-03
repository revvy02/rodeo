-- implementation based on Rust path library
-- https://github.com/rust-lang/rust/blob/bd7d328807a8bb15732ebb764e1ea3df4fbe3fd1/library/std/src/path.rs
local Disk = require('../luau_packages/luau_disk')

local Component = require('./Component')
local Components = require('./Components')
local Prefix = require('./Prefix')
local iterAfter = require('./iterAfter')
local sysPath = require('./sys/path')

local Array = Disk.Array

local isSepByte = sysPath.isSepByte
local parsePrefix = sysPath.parsePrefix
local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR

local IS_WINDOWS = MAIN_SEPARATOR_STR == '\\'

type Component = Component.Component
type Components = Components.Components
type Prefix = Prefix.Prefix

local function hasRedoxScheme(_s: string): boolean
    return false
end

export type Ancestors = {
    -- Iterator
    next: (self: Ancestors) -> Path?,
    collect: (self: Ancestors) -> { Path },
}

type AncestorsPrivate = {
    _next: Path?,
}
type PrivateAncestors = Ancestors & AncestorsPrivate

type AncestorsStatic = Ancestors & AncestorsPrivate & {
    new: () -> Ancestors,
}

local Ancestors: AncestorsStatic = {} :: any
local AncestorsMetatable = {
    __index = Ancestors,
}

local function newAncestors(path: Path?): Ancestors
    local self: AncestorsPrivate = {
        _next = path,
    }

    return setmetatable(self, AncestorsMetatable) :: any
end

function Ancestors:next(): Path?
    local self: PrivateAncestors = self :: any

    local next = self._next
    self._next = next and next:parent()

    return next
end

function Ancestors:collect(): { Path }
    local self: PrivateAncestors = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

export type AsPath = string | Path | Components

export type Path = {
    toString: (self: Path) -> string,

    toPathBuf: (self: Path) -> Path,
    isAbsolute: (self: Path) -> boolean,
    isRelative: (self: Path) -> boolean,
    hasRoot: (self: Path) -> boolean,
    parent: (self: Path) -> Path?,
    ancestors: (self: Path) -> Ancestors,
    fileName: (self: Path) -> string?,
    stripPrefix: (self: Path, base: AsPath) -> Path?,
    startsWith: (self: Path, base: AsPath) -> boolean,
    endsWith: (self: Path, child: AsPath) -> boolean,

    fileStem: (self: Path) -> string?,
    filePrefix: (self: Path) -> string?,
    extension: (self: Path) -> string?,
    join: (self: Path, path: AsPath) -> Path,

    withFileName: (self: Path, fileName: string) -> Path,
    withExtension: (self: Path, extension: string) -> Path,
    components: (self: Path) -> Components,

    equal: (self: Path, other: Path) -> boolean,

    -- PathBuf
    push: (self: Path, path: AsPath) -> (),
    pop: (self: Path) -> boolean,
    setFileName: (self: Path, fileName: string) -> (),
    setExtension: (self: Path, extension: string) -> boolean,
    clear: (self: Path) -> (),
}

type Private = {
    _inner: string,

    _prefix: (self: Path) -> Prefix?,
}
type PrivatePath = Path & Private

type PathStatic = Path & Private & {
    from: (path: AsPath) -> Path,
    new: (path: string) -> Path,
    is: (value: unknown) -> boolean,
}

local Path: PathStatic = {} :: any
local PathMetatable = {
    __index = Path,
    __tostring = function(self: Path): string
        return self:toString()
    end,
}

-- basic workhorse for splitting stem and extension
local function rsplitFileAtDot(file: string): (string?, string?)
    if file == '..' then
        return file, nil
    end

    -- The unsafety here stems from converting between &OsStr and &[u8]
    -- and back. This is safe to do because (1) we only look at ASCII
    -- contents of the encoding and (2) new &OsStr values are produced
    -- only from ASCII-bounded slices of existing &OsStr values.

    local reversed = string.reverse(file)
    local length = #file
    local revIndex = string.find(reversed, '.', 1, true)

    local index = revIndex and (1 + length - revIndex)

    if index == nil then
        return file, nil
    end

    local after = index and string.sub(file, index + 1)
    local before = index and string.sub(file, 1, index - 1)

    if before == '' then
        return file, nil
    else
        return before, after
    end
end

local function splitFileAtDot(file: string): (string, string?)
    if file == '..' then
        return file, nil
    end

    -- The unsafety here stems from converting between &OsStr and &[u8]
    -- and back. This is safe to do because (1) we only look at ASCII
    -- contents of the encoding and (2) new &OsStr values are produced
    -- only from ASCII-bounded slices of existing &OsStr values.
    local index = string.find(file, '.', 2, true)
    if index == nil then
        return file, nil
    else
        local before = string.sub(file, 1, index - 1)
        local after = string.sub(file, index + 1)

        return before, after
    end
end

-- Says whether the first byte after the prefix is a separator.
local function hasPhysicalRoot(s: string, prefix: Prefix?): boolean
    local path = if prefix ~= nil then string.sub(s, prefix:len() + 1) else s
    return path ~= '' and isSepByte(string.sub(path, 1, 1))
end

function Path.new(path: string): Path
    local self: Private = {
        _inner = path,

        _prefix = nil :: any,
    }

    return setmetatable(self, PathMetatable) :: any
end

function Path.from(path: AsPath): Path
    local pathType = type(path)
    if pathType == 'string' then
        return Path.new(path :: string)
    elseif Path.is(path) then
        return path :: Path
    elseif Components.is(path) then
        return Path.new(path:asPathString())
    end

    error('unable to create path from value')
end

function Path.is(value: unknown): boolean
    return type(value) == 'table' and getmetatable(value :: any) == PathMetatable
end

function Path:toString(): string
    local self: PrivatePath = self :: any

    return self._inner
end

function Path:toPathBuf(): Path
    local self: PrivatePath = self :: any

    return setmetatable(table.clone(self), PathMetatable) :: any
end

function Path:isAbsolute(): boolean
    local self: PrivatePath = self :: any

    -- if cfg!(target_os = "redox") then
    --     -- FIXME: Allow Redox prefixes
    --     return self:hasRoot() || hasRedoxScheme(self.as_u8_slice())
    -- else
    -- replaced `cfg!(any(unix, { target_os = 'wasi' })` with `(not IS_WINDOWS)`
    return self:hasRoot() and ((not IS_WINDOWS) or self:_prefix() ~= nil)
    -- end
end

function Path:isRelative(): boolean
    return not self:isAbsolute()
end

function Path:hasRoot(): boolean
    local self: PrivatePath = self :: any
    return self:components():hasRoot()
end

function Path:parent(): Path?
    local self: PrivatePath = self :: any
    local comps = self:components()
    local comp = comps:nextBack()

    if comp then
        local compType = comp.type

        if compType == 'normal' or compType == 'curDir' or compType == 'parentDir' then
            return Path.new(comps:asPathString())
        end
    end
    return nil
end

function Path:ancestors(): Ancestors
    local self: PrivatePath = self :: any

    return newAncestors(self)
end

function Path:fileName(): string?
    local components = self:components()
    local p = components:nextBack()

    return if p and p.type == 'normal' then (p :: any).value else nil
end

function Path:stripPrefix(base: AsPath): Path?
    local result: Components? = iterAfter(self:components(), Path.from(base):components())

    return result and Path.from(result:asPathString())
end

function Path:startsWith(base: AsPath): boolean
    return iterAfter(self:components(), Path.from(base):components()) ~= nil
end

function Path:endsWith(child: AsPath): boolean
    return iterAfter(self:components():rev(), Path.from(child):components():rev()) ~= nil
end

function Path:fileStem(): string?
    local fileName = self:fileName()

    if fileName then
        local before, after = rsplitFileAtDot(fileName)

        return before or after
    end

    return nil
end

function Path:filePrefix(): string?
    local fileName = self:fileName()

    if fileName then
        local before, after = splitFileAtDot(fileName)

        return before or after
    end

    return nil
end

function Path:extension(): string?
    local fileName = self:fileName()

    if fileName then
        local before, after = rsplitFileAtDot(fileName)

        return before and after
    end

    return nil
end

function Path:join(path: AsPath): Path
    local self: PrivatePath = self :: any

    local buf = self:toPathBuf()
    buf:push(path)
    return buf
end

function Path:withFileName(fileName: string): Path
    local self: PrivatePath = self :: any

    local buf = self:toPathBuf()
    buf:setFileName(fileName)
    return buf
end

function Path:withExtension(extension: string): Path
    local self: PrivatePath = self :: any

    local buf = self:toPathBuf()
    buf:setExtension(extension)
    return buf
end

function Path:components(): Components
    local self: PrivatePath = self :: any
    local prefix = parsePrefix(self._inner)
    return Components.new(
        self._inner,
        prefix,
        hasPhysicalRoot(self._inner, prefix) or hasRedoxScheme(self._inner)
    )
end

function Path:equal(other: Path): boolean
    local self: PrivatePath = self :: any
    return self:components():equal(other:components())
end

function Path:push(path: AsPath): ()
    local self: PrivatePath = self :: any

    local path = Path.from(path) :: PrivatePath

    -- in general, a separator is needed if the rightmost byte is not a separator
    local needSep = if self._inner == ''
        then false
        else not isSepByte(string.sub(self._inner, -1, -1))

    -- in the special case of `C:` on Windows, do *not* add a separator
    local comps = self:components()

    if
        comps:prefixLen() > 0
        and comps:prefixLen() == #(comps :: any)._path
        and (comps.prefix :: Prefix):isDrive()
    then
        needSep = false
    end

    -- absolute `path` replaces `self`
    if path:isAbsolute() or path:_prefix() ~= nil then
        self._inner = ''

    -- verbatim paths need . and .. removed
    elseif comps:prefixVerbatim() and path._inner ~= '' then
        local buf = comps:collect()
        for _, c in path:components():collect() do
            if c.type == 'rootDir' then
                buf = { buf[1], c :: any }
            elseif c.type == 'curDir' then
                -- do nothing
            elseif c.type == 'parentDir' then
                local lastIndex = #buf
                if lastIndex > 0 and buf[lastIndex].type == 'normal' then
                    table.remove(buf)
                end
            else
                table.insert(buf, c :: any)
            end
        end

        local res = {}
        local needSep = false

        for _, c: Component in buf :: { any } do
            if needSep and c.type ~= 'rootDir' then
                table.insert(res, MAIN_SEPARATOR_STR)
            end
            table.insert(res, c:toString())

            local prefix: Prefix = (c :: any).parsed
            needSep = if c.type == 'rootDir'
                then false
                elseif prefix then not prefix:isDrive() and prefix:len() > 0
                else true
        end

        self._inner = table.concat(res, '')
        return

    -- `path` has a root but no prefix, e.g., `\windows` (Windows only)
    elseif path:hasRoot() then
        local prefix_len = self:components():prefixRemaining()

        self._inner = string.sub(self._inner, 1, prefix_len)

    -- `path` is a pure relative path
    elseif needSep then
        self._inner ..= MAIN_SEPARATOR_STR
    end

    self._inner ..= path._inner
end

function Path:pop(): boolean
    local self: PrivatePath = self :: any
    local parent = self:parent() :: PrivatePath?
    if parent ~= nil then
        self._inner = parent._inner
        return true
    else
        return false
    end
end

function Path:setFileName(fileName: string)
    local self: PrivatePath = self :: any

    if self:fileName() ~= nil then
        self:pop()
    end
    self:push(fileName)
end

function Path:setExtension(extension: string): boolean
    local self: PrivatePath = self :: any

    local fileStem = self:fileStem()

    if fileStem == nil then
        return false
    end

    self:pop()
    -- add the new extension, if any
    self:push(if extension ~= '' then fileStem .. '.' .. extension else fileStem)

    return true
end

function Path:clear()
    local self: PrivatePath = self :: any
    self._inner = ''
end

function Path:_prefix(): Prefix?
    local self: PrivatePath = self :: any
    return self:components().prefix
end

return Path
