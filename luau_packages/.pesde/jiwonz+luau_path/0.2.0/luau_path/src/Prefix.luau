export type PrefixEnum =
    { type: 'Verbatim', value: string }
    | { type: 'VerbatimUNC', hostName: string, shareName: string }
    | { type: 'VerbatimDisk', value: string }
    | { type: 'DeviceNS', value: string }
    | { type: 'UNC', hostName: string, shareName: string }
    | { type: 'Disk', value: string }

export type Prefix = PrefixEnum & {
    len: (self: Prefix) -> number,
    isVerbatim: (self: Prefix) -> boolean,
    isDrive: (self: Prefix) -> boolean,
    hasImplicitRoot: (self: Prefix) -> boolean,

    clone: (self: Prefix) -> Prefix,
    equal: (self: Prefix, other: Prefix) -> boolean,
}

type PrefixStatic = Prefix & {
    Verbatim: (value: string) -> Prefix,
    VerbatimUNC: (hostName: string, shareName: string) -> Prefix,
    VerbatimDisk: (value: string) -> Prefix,
    DeviceNS: (value: string) -> Prefix,
    UNC: (hostName: string, shareName: string) -> Prefix,
    Disk: (value: string) -> Prefix,
}

local Prefix: PrefixStatic = {} :: any
local PrefixMetatable = {
    __index = Prefix,
    __eq = function(self: Prefix, other: Prefix): boolean
        return self:equal(other)
    end,
}

local function new(self: PrefixEnum)
    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix.Verbatim(value: string): Prefix
    return new({ type = 'Verbatim', value = value })
end

function Prefix.VerbatimUNC(hostName: string, shareName: string): Prefix
    return new({ type = 'VerbatimUNC', hostName = hostName, shareName = shareName })
end

function Prefix.VerbatimDisk(value: string): Prefix
    return new({ type = 'VerbatimDisk', value = value })
end

function Prefix.DeviceNS(value: string): Prefix
    return new({ type = 'DeviceNS', value = value })
end

function Prefix.UNC(hostName: string, shareName: string): Prefix
    return new({ type = 'UNC', hostName = hostName, shareName = shareName })
end

function Prefix.Disk(value: string): Prefix
    return new({ type = 'Disk', value = value })
end

function Prefix:len(): number
    local selfType = self.type
    if selfType == 'Verbatim' then
        return 4 + string.len((self :: any).value)
    elseif selfType == 'VerbatimUNC' then
        local data: { hostName: string, shareName: string } = self :: any
        local shareNameLen = string.len(data.shareName)
        return 8 + string.len(data.hostName) + if shareNameLen > 0 then 1 + shareNameLen else 0
    elseif selfType == 'VerbatimDisk' then
        return 6
    elseif selfType == 'UNC' then
        local data: { hostName: string, shareName: string } = self :: any
        local shareNameLen = string.len(data.shareName)
        return 2 + string.len(data.hostName) + if shareNameLen > 0 then 1 + shareNameLen else 0
    elseif selfType == 'DeviceNS' then
        return 4 + string.len((self :: any).value)
    elseif selfType == 'Disk' then
        return 2
    elseif _G.DEV then
        error('unreachable')
    end
    return 0
end

function Prefix:isVerbatim(): boolean
    local selfType = self.type
    return selfType == 'Verbatim' or selfType == 'VerbatimDisk' or selfType == 'VerbatimUNC'
end

function Prefix:isDrive(): boolean
    return self.type == 'Disk'
end

function Prefix:hasImplicitRoot(): boolean
    return self.type ~= 'Disk'
end

function Prefix:clone(): Prefix
    local self = table.clone(self)

    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix:equal(other: Prefix): boolean
    local selfType = self.type

    if selfType ~= other.type then
        return false
    end

    if selfType == 'Verbatim' then
        return (self :: any).value == (other :: any).value
    end
    if selfType == 'VerbatimUNC' then
        return (self :: any).hostName == (other :: any).hostName
            and (self :: any).shareName == (other :: any).shareName
    end
    if selfType == 'VerbatimDisk' then
        return (self :: any).value == (other :: any).value
    end
    if selfType == 'DeviceNS' then
        return (self :: any).value == (other :: any).value
    end
    if selfType == 'UNC' then
        return (self :: any).hostName == (other :: any).hostName
            and (self :: any).shareName == (other :: any).shareName
    end
    if selfType == 'Disk' then
        return (self :: any).value == (other :: any).value
    end

    return true
end

return Prefix
