local Prefix = require("./Prefix")

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

export type ComponentStatic = Component & {
    normal: (value: string) -> Component,
    rootDir: () -> Component,
    curDir: () -> Component,
    parentDir: () -> Component,
    prefix: (raw: string, prefix: Prefix) -> Component,
}

return nil
