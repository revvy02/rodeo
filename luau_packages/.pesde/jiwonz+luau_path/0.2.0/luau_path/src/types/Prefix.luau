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

return nil
