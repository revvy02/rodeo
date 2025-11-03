local PrefixParserSlice = require('./PrefixParserSlice')

type PrefixParserSlice = PrefixParserSlice.PrefixParserSlice

export type PrefixParser = {
    asSlice: (self: PrefixParser) -> PrefixParserSlice,
}

type Private = {
    _path: string,
    _prefix: string,
    _length: number,
}
type PrivatePrefixParser = PrefixParser & Private

type PrefixParserStatic = PrefixParser & Private & {
    new: (path: string, length: number) -> PrefixParser,
    getPrefix: (path: string, length: number) -> string,
}

local PrefixParser: PrefixParserStatic = {} :: any
local PrefixParserMetatable = {
    __index = PrefixParser,
}

function PrefixParser.new(path: string, length: number): PrefixParser
    local self: Private = {
        _path = path,
        _prefix = PrefixParser.getPrefix(path, length),
        _length = length,
    }

    return setmetatable(self, PrefixParserMetatable) :: any
end

function PrefixParser.getPrefix(path: string, length: number): string
    local prefix = string.gsub(string.sub(path, 1, length), '/', '\\')
    return prefix
end

function PrefixParser:asSlice(): PrefixParserSlice
    local self: PrivatePrefixParser = self :: any

    return PrefixParserSlice.new(self._path, string.sub(self._prefix, 1, math.min(#self._path, 8)))
end

return PrefixParser
