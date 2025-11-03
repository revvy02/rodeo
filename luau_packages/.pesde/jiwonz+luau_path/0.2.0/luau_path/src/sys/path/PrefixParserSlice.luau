export type PrefixParserSlice = {
    stripPrefix: (self: PrefixParserSlice, prefix: string) -> PrefixParserSlice?,
    prefixBytes: (self: PrefixParserSlice) -> string,
    finish: (self: PrefixParserSlice) -> string,
}

type Private = {
    _path: string,
    _prefix: string,
    _index: number,
}
type PrivatePrefixParserSlice = PrefixParserSlice & Private

type PrefixParserSliceStatic = PrefixParserSlice & Private & {
    new: (path: string, prefix: string) -> PrefixParserSlice,
}

local PrefixParserSlice: PrefixParserSliceStatic = {} :: any
local PrefixParserSliceMetatable = {
    __index = PrefixParserSlice,
}

function PrefixParserSlice.new(path: string, prefix: string): PrefixParserSlice
    local self: Private = {
        _path = path,
        _prefix = prefix,
        _index = 1,
    }

    return setmetatable(self, PrefixParserSliceMetatable) :: any
end

function PrefixParserSlice:stripPrefix(prefix: string): PrefixParserSlice?
    local self: PrivatePrefixParserSlice = self :: any

    local prefixLength = #prefix
    if string.sub(self._prefix, self._index, self._index + prefixLength - 1) == prefix then
        local self: Private = {
            _path = self._path,
            _prefix = self._prefix,
            _index = self._index + prefixLength,
        }

        return setmetatable(self, PrefixParserSliceMetatable) :: any
    end
    return nil
end

function PrefixParserSlice:prefixBytes(): string
    local self: PrivatePrefixParserSlice = self :: any

    return string.sub(self._path, 1, self._index)
end

function PrefixParserSlice:finish(): string
    local self: PrivatePrefixParserSlice = self :: any

    return string.sub(self._path, self._index)
end

return PrefixParserSlice
