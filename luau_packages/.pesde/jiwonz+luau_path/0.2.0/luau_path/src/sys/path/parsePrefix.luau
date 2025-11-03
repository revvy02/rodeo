-- https://github.com/rust-lang/rust/blob/master/library/std/src/sys/path/windows.rs

local Prefix = require('../../Prefix')
local PrefixParser = require('./PrefixParser')

type Prefix = Prefix.Prefix
type PrefixParser = PrefixParser.PrefixParser

local function isValidDriveLetter(char: string): boolean
    local charByte = string.byte(char)
    return (charByte >= 65 and charByte <= 90) or (charByte >= 97 and charByte <= 122)
end

local function parseDrive(path: string): string?
    local drive = string.sub(path, 1, 1)

    if drive ~= '' and isValidDriveLetter(drive) and string.sub(path, 2, 2) == ':' then
        return string.upper(drive)
    end

    return nil
end

local function parseDriveExact(path: string): string?
    local thirdChar = string.sub(path, 3, 3)
    if thirdChar == '/' or thirdChar == '\\' then
        return parseDrive(path)
    else
        return nil
    end
end

local function findSepByte(content: string): number?
    local slash = string.find(content, '/', 1, true)
    local backSlash = string.find(content, '\\', 1, true)

    if slash and backSlash then
        return math.min(slash, backSlash)
    end

    return slash or backSlash
end

local function findVerbatimSep(content: string): number?
    local index = string.find(content, '\\', 1, true)
    return index
end

local function parseNextComponent(path: string, verbatim: boolean): (string, string)
    -- local separator = if verbatim then isVerbatimSep else isSepByte
    local findSeparator: (string) -> number? = if verbatim then findVerbatimSep else findSepByte

    local separatorStart = findSeparator(path)

    if separatorStart then
        local separatorEnd = separatorStart + 1

        local component = string.sub(path, 1, separatorStart - 1)

        -- Panic safe
        -- The max `separator_end` is `bytes.len()` and `bytes[bytes.len()..]` is a valid index.
        local path = string.sub(path, separatorEnd)

        -- SAFETY: `path` is a valid wtf8 encoded slice and each of the separators ('/', '\')
        -- is encoded in a single byte, therefore `bytes[separator_start]` and
        -- `bytes[separator_end]` must be code point boundaries and thus
        -- `bytes[..separator_start]` and `bytes[separator_end..]` are valid wtf8 slices.
        return component, path
    else
        return path, ''
    end
end

local function parsePrefix(path: string): Prefix?
    local parser = PrefixParser.new(path, 8)
    local parser = parser:asSlice()

    local parser = parser:stripPrefix([[\\]])

    if parser then
        -- \\

        -- The meaning of verbatim paths can change when they use a different
        -- separator.
        local nextParser = parser:stripPrefix([[?\]])

        if nextParser and string.find(nextParser:prefixBytes(), '/', 1, true) == nil then
            -- \\?\
            local uncParser = nextParser:stripPrefix([[UNC\]])
            if uncParser then
                -- \\?\UNC\server\share

                local path = uncParser:finish()
                local server, path = parseNextComponent(path, true)
                local share, _ = parseNextComponent(path, true)

                return Prefix.VerbatimUNC(server, share)
            else
                local path = nextParser:finish()

                -- in verbatim paths only recognize an exact drive prefix
                local drive = parseDriveExact(path)
                if drive then
                    -- \\?\C:
                    return Prefix.VerbatimDisk(drive)
                else
                    -- \\?\prefix
                    local prefix = parseNextComponent(path, true)
                    return Prefix.Verbatim(prefix)
                end
            end
        end

        local nextParser = parser:stripPrefix([[.\]])

        if nextParser then
            -- \\.\COM42
            local path = nextParser:finish()
            local prefix, _ = parseNextComponent(path, false)
            return Prefix.DeviceNS(prefix)
        end

        local path = parser:finish()
        local server, path = parseNextComponent(path, false)
        local share, _ = parseNextComponent(path, false)

        if server ~= '' and share ~= '' then
            return Prefix.UNC(server, share)
        else
            -- no valid prefix beginning with "\\" recognized
            return nil
        end
    else
        -- If it has a drive like `C:` then it's a disk.
        -- Otherwise there is no prefix.
        local drive = parseDrive(path)
        return drive and Prefix.Disk(drive)
    end
end

return parsePrefix
