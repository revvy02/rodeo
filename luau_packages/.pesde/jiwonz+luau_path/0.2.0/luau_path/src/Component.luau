local Prefix = require('./Prefix')
local sysPath = require('./sys/path')

local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR

type Prefix = Prefix.Prefix

export type PrefixComponent = {
    type: 'prefix',
    raw: string,
    parsed: Prefix,
}
type NormalComponent = { type: 'normal', value: string }

type ComponentEnum =
    NormalComponent
    | { type: 'rootDir' }
    | { type: 'curDir' }
    | { type: 'parentDir' }
    | PrefixComponent

type ComponentCommon = {
    toString: (self: Component) -> string,
    equal: (self: Component, other: Component) -> boolean,
}

export type Component = ComponentEnum & ComponentCommon

type ComponentStatic = Component & {
    normal: (value: string) -> Component,
    rootDir: () -> Component,
    curDir: () -> Component,
    parentDir: () -> Component,
    prefix: (raw: string, prefix: Prefix) -> Component,
}

local Component: ComponentStatic = {} :: any
local ComponentMetatable = {
    __index = Component,
    __tostring = function(self)
        return self:toString()
    end,
    __eq = function(self: Prefix, other: Prefix): boolean
        return self:equal(other)
    end,
}

function Component.normal(value: string): Component
    local self: ComponentEnum = { type = 'normal', value = value }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.rootDir(): Component
    local self: ComponentEnum = { type = 'rootDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.curDir(): Component
    local self: ComponentEnum = { type = 'curDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.parentDir(): Component
    local self: ComponentEnum = { type = 'parentDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.prefix(raw: string, prefix: Prefix): Component
    local self: PrefixComponent = { type = 'prefix', raw = raw, parsed = prefix }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component:toString(): string
    local componentType = self.type
    return if componentType == 'normal'
        then (self :: NormalComponent & ComponentCommon).value
        elseif componentType == 'curDir' then '.'
        elseif componentType == 'parentDir' then '..'
        elseif componentType == 'rootDir' then MAIN_SEPARATOR_STR
        else (self :: PrefixComponent & ComponentCommon).raw
end

function Component:equal(other: Component): boolean
    local selfType = self.type

    if selfType ~= other.type then
        return false
    end

    if selfType == 'normal' then
        return (self :: NormalComponent & ComponentCommon).value
            == (other :: NormalComponent & ComponentCommon).value
    elseif selfType == 'prefix' then
        return (self :: PrefixComponent & ComponentCommon).parsed:equal(
            (other :: PrefixComponent & ComponentCommon).parsed
        )
    end

    return true
end

return Component
