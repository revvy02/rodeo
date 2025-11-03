local Prefix = require('../Prefix')
local parsePrefixWindows = require('@self/parsePrefix')

type Prefix = Prefix.Prefix

local MAIN_SEPARATOR_STR = if _G.SYS_PATH_SEPARATOR == '\\'
        or _G.SYS_PATH_SEPARATOR == '/'
    then _G.SYS_PATH_SEPARATOR
    elseif _G.LUA_ENV == 'lune' and (require :: any)('@lune/process').os == 'windows' then '\\'
    else '/'

local IS_WINDOWS = MAIN_SEPARATOR_STR == '\\'

local function isSepByteUnix(b: string): boolean
    return b == '/'
end

local function isSepByteWindows(b: string): boolean
    return b == '/' or b == '\\'
end

local function isVerbatimSepUnix(b: string): boolean
    return b == '/'
end

local function isVerbatimSepWindows(b: string): boolean
    return b == '\\'
end

local isSepByte: (string) -> boolean = if IS_WINDOWS then isSepByteWindows else isSepByteUnix
local isVerbatimSep: (string) -> boolean = if IS_WINDOWS
    then isVerbatimSepWindows
    else isVerbatimSepUnix

local function parsePrefixUnix(_path: string): Prefix?
    return nil
end

local parsePrefix: (path: string) -> Prefix? = if IS_WINDOWS
    then parsePrefixWindows
    else parsePrefixUnix

return {
    MAIN_SEPARATOR_STR = MAIN_SEPARATOR_STR,
    isSepByte = isSepByte,
    isVerbatimSep = isVerbatimSep,
    parsePrefix = parsePrefix,
}
