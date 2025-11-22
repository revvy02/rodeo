type Set__DARKLUA_TYPE_a<T> = { [T]: true }

type reduceFromFirstValue__DARKLUA_TYPE_b = <T>(
    array: { T },
    reducer: (accumulator: T, value: T, index: number) -> T
) -> T?

type reduceWithAccumulator__DARKLUA_TYPE_c = <T, A>(
    array: { T },
    reducer: (accumulator: A, value: T, index: number) -> A,
    accumulator: A
) -> A

type alternate1__DARKLUA_TYPE_d = <A>({ A }) -> { A }

type alternate2__DARKLUA_TYPE_e = <A, B>({ A }, { B }) -> { A | B }

type alternate3__DARKLUA_TYPE_f = <A, B, C>({ A }, { B }, { C }) -> { A | B | C }

type alternateAll__DARKLUA_TYPE_g = <T, U, V...>({ T },V...) -> { U }

type KeyElement__DARKLUA_TYPE_h<K, V> = { key: K, element: V }

type zip1__DARKLUA_TYPE_i = <A>({ A }) -> { { A } }

type zip2__DARKLUA_TYPE_j = <A, B>({ A }, { B }) -> { { A | B } }

type zip3__DARKLUA_TYPE_k = <A, B, C>({ A }, { B }, { C }) -> { { A | B | C } }

type zipAll__DARKLUA_TYPE_l = <T, U>({ T },...{ U }) -> { { T | U } }

type EntriesFn__DARKLUA_TYPE_m =
    (<K, V>(map: { [K]: V }) -> { { K | V } })
    & (<K, V, T, U>(map: { [K]: V }, keyIndex: T, valueIndex: U) -> { { [(T | U)]: K | V } })

type merge1__DARKLUA_TYPE_n = <A>(A) -> A

type merge2__DARKLUA_TYPE_o = <A, B>(A, B) -> A & B

type merge3__DARKLUA_TYPE_p = <A, B, C>(A, B, C) -> A & B & C

type merge4__DARKLUA_TYPE_q = <A, B, C, D>(A, B, C, D) -> A & B & C & D

type merge5__DARKLUA_TYPE_r = <A, B, C, D, E>(A, B, C, D, E) -> A & B & C & D & E

type mergeAll__DARKLUA_TYPE_s = <T, U, V...>(T,V...) -> U

type Set__DARKLUA_TYPE_t<T> = Set__DARKLUA_TYPE_a<T>

type Set__DARKLUA_TYPE_u<T> = Set__DARKLUA_TYPE_a<T>

type Set__DARKLUA_TYPE_v<T> = Set__DARKLUA_TYPE_u<T>

type PrefixEnum__DARKLUA_TYPE_w =
    { type: 'Verbatim', value: string }
    | { type: 'VerbatimUNC', hostName: string, shareName: string }
    | { type: 'VerbatimDisk', value: string }
    | { type: 'DeviceNS', value: string }
    | { type: 'UNC', hostName: string, shareName: string }
    | { type: 'Disk', value: string }

type Prefix__DARKLUA_TYPE_x = PrefixEnum__DARKLUA_TYPE_w & {
    len: (self: Prefix__DARKLUA_TYPE_x) -> number,
    isVerbatim: (self: Prefix__DARKLUA_TYPE_x) -> boolean,
    isDrive: (self: Prefix__DARKLUA_TYPE_x) -> boolean,
    hasImplicitRoot: (self: Prefix__DARKLUA_TYPE_x) -> boolean,

    clone: (self: Prefix__DARKLUA_TYPE_x) -> Prefix__DARKLUA_TYPE_x,
    equal: (self: Prefix__DARKLUA_TYPE_x, other: Prefix__DARKLUA_TYPE_x) -> boolean,
}

type PrefixStatic__DARKLUA_TYPE_y = Prefix__DARKLUA_TYPE_x & {
    Verbatim: (value: string) -> Prefix__DARKLUA_TYPE_x,
    VerbatimUNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_x,
    VerbatimDisk: (value: string) -> Prefix__DARKLUA_TYPE_x,
    DeviceNS: (value: string) -> Prefix__DARKLUA_TYPE_x,
    UNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_x,
    Disk: (value: string) -> Prefix__DARKLUA_TYPE_x,
}

type PrefixParserSlice__DARKLUA_TYPE_z = {
    stripPrefix: (self: PrefixParserSlice__DARKLUA_TYPE_z, prefix: string) -> PrefixParserSlice__DARKLUA_TYPE_z?,
    prefixBytes: (self: PrefixParserSlice__DARKLUA_TYPE_z) -> string,
    finish: (self: PrefixParserSlice__DARKLUA_TYPE_z) -> string,
}

type Private__DARKLUA_TYPE_A = {
    _path: string,
    _prefix: string,
    _index: number,
}

type PrivatePrefixParserSlice__DARKLUA_TYPE_B = PrefixParserSlice__DARKLUA_TYPE_z & Private__DARKLUA_TYPE_A

type PrefixParserSliceStatic__DARKLUA_TYPE_C = PrefixParserSlice__DARKLUA_TYPE_z & Private__DARKLUA_TYPE_A & {
    new: (path: string, prefix: string) -> PrefixParserSlice__DARKLUA_TYPE_z,
}

type PrefixParserSlice__DARKLUA_TYPE_D = PrefixParserSlice__DARKLUA_TYPE_z
type PrefixParser__DARKLUA_TYPE_E = {
    asSlice: (self: PrefixParser__DARKLUA_TYPE_E) -> PrefixParserSlice__DARKLUA_TYPE_D,
}

type Private__DARKLUA_TYPE_F = {
    _path: string,
    _prefix: string,
    _length: number,
}

type PrivatePrefixParser__DARKLUA_TYPE_G = PrefixParser__DARKLUA_TYPE_E & Private__DARKLUA_TYPE_F

type PrefixParserStatic__DARKLUA_TYPE_H = PrefixParser__DARKLUA_TYPE_E & Private__DARKLUA_TYPE_F & {
    new: (path: string, length: number) -> PrefixParser__DARKLUA_TYPE_E,
    getPrefix: (path: string, length: number) -> string,
}

type Prefix__DARKLUA_TYPE_I = Prefix__DARKLUA_TYPE_x
type PrefixParser__DARKLUA_TYPE_J = PrefixParser__DARKLUA_TYPE_E
type Prefix__DARKLUA_TYPE_K = Prefix__DARKLUA_TYPE_x
type Prefix__DARKLUA_TYPE_L = Prefix__DARKLUA_TYPE_x
type PrefixComponent__DARKLUA_TYPE_M = {
    type: 'prefix',
    raw: string,
    parsed: Prefix__DARKLUA_TYPE_L,
}

type NormalComponent__DARKLUA_TYPE_N = { type: 'normal', value: string }

type ComponentEnum__DARKLUA_TYPE_O =
    NormalComponent__DARKLUA_TYPE_N
    | { type: 'rootDir' }
    | { type: 'curDir' }
    | { type: 'parentDir' }
    | PrefixComponent__DARKLUA_TYPE_M

type ComponentCommon__DARKLUA_TYPE_P = {
    toString: (self: Component__DARKLUA_TYPE_Q) -> string,
    equal: (self: Component__DARKLUA_TYPE_Q, other: Component__DARKLUA_TYPE_Q) -> boolean,
}

type Component__DARKLUA_TYPE_Q = ComponentEnum__DARKLUA_TYPE_O & ComponentCommon__DARKLUA_TYPE_P

type ComponentStatic__DARKLUA_TYPE_R = Component__DARKLUA_TYPE_Q & {
    normal: (value: string) -> Component__DARKLUA_TYPE_Q,
    rootDir: () -> Component__DARKLUA_TYPE_Q,
    curDir: () -> Component__DARKLUA_TYPE_Q,
    parentDir: () -> Component__DARKLUA_TYPE_Q,
    prefix: (raw: string, prefix: Prefix__DARKLUA_TYPE_L) -> Component__DARKLUA_TYPE_Q,
}

type Rev__DARKLUA_TYPE_S<T> = {
    next: (self: Rev__DARKLUA_TYPE_S<T>) -> T?,
    collect: (self: Rev__DARKLUA_TYPE_S<T>) -> { T },
    rev: (self: Rev__DARKLUA_TYPE_S<T>) -> Rev__DARKLUA_TYPE_S<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev__DARKLUA_TYPE_S<T>) -> T?,

    clone: (self: Rev__DARKLUA_TYPE_S<T>) -> Rev__DARKLUA_TYPE_S<T>,
}

type DoubleEndedIterator__DARKLUA_TYPE_T<T> = {
    next: (self: DoubleEndedIterator__DARKLUA_TYPE_T<T>) -> T?,
    nextBack: (self: DoubleEndedIterator__DARKLUA_TYPE_T<T>) -> T?,

    clone: (self: DoubleEndedIterator__DARKLUA_TYPE_T<T>) -> DoubleEndedIterator__DARKLUA_TYPE_T<T>,
}

type Private__DARKLUA_TYPE_U<T> = {
    _iter: DoubleEndedIterator__DARKLUA_TYPE_T<T>,
}

type PrivateRev__DARKLUA_TYPE_V<T> = Rev__DARKLUA_TYPE_S<T> & Private__DARKLUA_TYPE_U<T>

type RevStatic__DARKLUA_TYPE_W = {
    new: <T>(iter: DoubleEndedIterator__DARKLUA_TYPE_T<T>) -> Rev__DARKLUA_TYPE_S<T>,

    next: <T>(self: Rev__DARKLUA_TYPE_S<T>) -> T?,
    collect: <T>(self: Rev__DARKLUA_TYPE_S<T>) -> { T },
    rev: <T>(self: Rev__DARKLUA_TYPE_S<T>) -> Rev__DARKLUA_TYPE_S<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev__DARKLUA_TYPE_S<T>) -> T?,

    clone: <T>(self: Rev__DARKLUA_TYPE_S<T>) -> Rev__DARKLUA_TYPE_S<T>,
}

type Component__DARKLUA_TYPE_X = Component__DARKLUA_TYPE_Q
type Prefix__DARKLUA_TYPE_Y = Prefix__DARKLUA_TYPE_x
type Rev__DARKLUA_TYPE_Z<T> = Rev__DARKLUA_TYPE_S<T>

type char__DARKLUA_TYPE__ = string

type Components__DARKLUA_TYPE_0 = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix__DARKLUA_TYPE_Y?,

    prefixLen: (self: Components__DARKLUA_TYPE_0) -> number,
    prefixVerbatim: (self: Components__DARKLUA_TYPE_0) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components__DARKLUA_TYPE_0) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components__DARKLUA_TYPE_0) -> number,
    -- is the iteration complete?
    finished: (self: Components__DARKLUA_TYPE_0) -> boolean,
    isSepByte: (self: Components__DARKLUA_TYPE_0, b: char__DARKLUA_TYPE__) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components__DARKLUA_TYPE_0) -> string,
    hasRoot: (self: Components__DARKLUA_TYPE_0) -> boolean,
    includeCurDir: (self: Components__DARKLUA_TYPE_0) -> boolean,
    parseSingleComponent: (self: Components__DARKLUA_TYPE_0, comp: string) -> Component__DARKLUA_TYPE_X?,
    parseNextComponent: (self: Components__DARKLUA_TYPE_0) -> (number, Component__DARKLUA_TYPE_X?),
    parseNextComponentBack: (self: Components__DARKLUA_TYPE_0) -> (number, Component__DARKLUA_TYPE_X?),
    trimLeft: (self: Components__DARKLUA_TYPE_0) -> (),
    trimRight: (self: Components__DARKLUA_TYPE_0) -> (),

    -- Iterator
    next: (self: Components__DARKLUA_TYPE_0) -> Component__DARKLUA_TYPE_X?,
    collect: (self: Components__DARKLUA_TYPE_0) -> { Component__DARKLUA_TYPE_X },
    rev: (self: Components__DARKLUA_TYPE_0) -> Rev__DARKLUA_TYPE_Z<Component__DARKLUA_TYPE_X>,
    -- DoubleEndedIterator
    nextBack: (self: Components__DARKLUA_TYPE_0) -> Component__DARKLUA_TYPE_X?,

    -- Clone
    clone: (self: Components__DARKLUA_TYPE_0) -> Components__DARKLUA_TYPE_0,
    equal: (self: Components__DARKLUA_TYPE_0, other: Components__DARKLUA_TYPE_0) -> boolean,
}

type IterComponents__DARKLUA_TYPE_1 = (items: { Component__DARKLUA_TYPE_X }, index: number?) -> (number?, Component__DARKLUA_TYPE_X)

type State__DARKLUA_TYPE_2 = 'Prefix' | 'StartDir' | 'Body' | 'Done'

type Private__DARKLUA_TYPE_3 = {
    -- The path left to parse components from
    _path: string,

    -- true if path *physically* has a root separator; for most Windows
    -- prefixes, it may have a "logical" root separator for the purposes of
    -- normalization, e.g., \\server\share == \\server\share\.
    _hasPhysicalRoot: boolean,

    -- The iterator is double-ended, and these two states keep track of what has
    -- been produced from either end
    _front: State__DARKLUA_TYPE_2,
    _back: State__DARKLUA_TYPE_2,
}

type PrivateComponents__DARKLUA_TYPE_4 = Components__DARKLUA_TYPE_0 & Private__DARKLUA_TYPE_3

type ComponentsStatic__DARKLUA_TYPE_5 = Components__DARKLUA_TYPE_0 & Private__DARKLUA_TYPE_3 & {
    new: (path: string, prefix: Prefix__DARKLUA_TYPE_Y?, hasPhysicalRoot: boolean) -> Components__DARKLUA_TYPE_0,
    is: (value: unknown) -> boolean,
}

type Component__DARKLUA_TYPE_6 = Component__DARKLUA_TYPE_Q
type ComponentIterator__DARKLUA_TYPE_7 = { next: (self: ComponentIterator__DARKLUA_TYPE_7) -> Component__DARKLUA_TYPE_6? }

type Clone__DARKLUA_TYPE_8<T> = { clone: (T) -> T }

type Component__DARKLUA_TYPE_9 = Component__DARKLUA_TYPE_Q
type Components__DARKLUA_TYPE_aa = Components__DARKLUA_TYPE_0
type Prefix__DARKLUA_TYPE_ab = Prefix__DARKLUA_TYPE_x
type Ancestors__DARKLUA_TYPE_ac = {
    -- Iterator
    next: (self: Ancestors__DARKLUA_TYPE_ac) -> Path__DARKLUA_TYPE_ah?,
    collect: (self: Ancestors__DARKLUA_TYPE_ac) -> { Path__DARKLUA_TYPE_ah },
}

type AncestorsPrivate__DARKLUA_TYPE_ad = {
    _next: Path__DARKLUA_TYPE_ah?,
}

type PrivateAncestors__DARKLUA_TYPE_ae = Ancestors__DARKLUA_TYPE_ac & AncestorsPrivate__DARKLUA_TYPE_ad

type AncestorsStatic__DARKLUA_TYPE_af = Ancestors__DARKLUA_TYPE_ac & AncestorsPrivate__DARKLUA_TYPE_ad & {
    new: () -> Ancestors__DARKLUA_TYPE_ac,
}

type AsPath__DARKLUA_TYPE_ag = string | Path__DARKLUA_TYPE_ah | Components__DARKLUA_TYPE_aa

type Path__DARKLUA_TYPE_ah = {
    toString: (self: Path__DARKLUA_TYPE_ah) -> string,

    toPathBuf: (self: Path__DARKLUA_TYPE_ah) -> Path__DARKLUA_TYPE_ah,
    isAbsolute: (self: Path__DARKLUA_TYPE_ah) -> boolean,
    isRelative: (self: Path__DARKLUA_TYPE_ah) -> boolean,
    hasRoot: (self: Path__DARKLUA_TYPE_ah) -> boolean,
    parent: (self: Path__DARKLUA_TYPE_ah) -> Path__DARKLUA_TYPE_ah?,
    ancestors: (self: Path__DARKLUA_TYPE_ah) -> Ancestors__DARKLUA_TYPE_ac,
    fileName: (self: Path__DARKLUA_TYPE_ah) -> string?,
    stripPrefix: (self: Path__DARKLUA_TYPE_ah, base: AsPath__DARKLUA_TYPE_ag) -> Path__DARKLUA_TYPE_ah?,
    startsWith: (self: Path__DARKLUA_TYPE_ah, base: AsPath__DARKLUA_TYPE_ag) -> boolean,
    endsWith: (self: Path__DARKLUA_TYPE_ah, child: AsPath__DARKLUA_TYPE_ag) -> boolean,

    fileStem: (self: Path__DARKLUA_TYPE_ah) -> string?,
    filePrefix: (self: Path__DARKLUA_TYPE_ah) -> string?,
    extension: (self: Path__DARKLUA_TYPE_ah) -> string?,
    join: (self: Path__DARKLUA_TYPE_ah, path: AsPath__DARKLUA_TYPE_ag) -> Path__DARKLUA_TYPE_ah,

    withFileName: (self: Path__DARKLUA_TYPE_ah, fileName: string) -> Path__DARKLUA_TYPE_ah,
    withExtension: (self: Path__DARKLUA_TYPE_ah, extension: string) -> Path__DARKLUA_TYPE_ah,
    components: (self: Path__DARKLUA_TYPE_ah) -> Components__DARKLUA_TYPE_aa,

    equal: (self: Path__DARKLUA_TYPE_ah, other: Path__DARKLUA_TYPE_ah) -> boolean,

    -- PathBuf
    push: (self: Path__DARKLUA_TYPE_ah, path: AsPath__DARKLUA_TYPE_ag) -> (),
    pop: (self: Path__DARKLUA_TYPE_ah) -> boolean,
    setFileName: (self: Path__DARKLUA_TYPE_ah, fileName: string) -> (),
    setExtension: (self: Path__DARKLUA_TYPE_ah, extension: string) -> boolean,
    clear: (self: Path__DARKLUA_TYPE_ah) -> (),
}

type Private__DARKLUA_TYPE_ai = {
    _inner: string,

    _prefix: (self: Path__DARKLUA_TYPE_ah) -> Prefix__DARKLUA_TYPE_ab?,
}

type PrivatePath__DARKLUA_TYPE_aj = Path__DARKLUA_TYPE_ah & Private__DARKLUA_TYPE_ai

type PathStatic__DARKLUA_TYPE_ak = Path__DARKLUA_TYPE_ah & Private__DARKLUA_TYPE_ai & {
    from: (path: AsPath__DARKLUA_TYPE_ag) -> Path__DARKLUA_TYPE_ah,
    new: (path: string) -> Path__DARKLUA_TYPE_ah,
    is: (value: unknown) -> boolean,
}

type PrefixEnum__DARKLUA_TYPE_al =
    { type: 'Verbatim', value: string }
    | { type: 'VerbatimUNC', hostName: string, shareName: string }
    | { type: 'VerbatimDisk', value: string }
    | { type: 'DeviceNS', value: string }
    | { type: 'UNC', hostName: string, shareName: string }
    | { type: 'Disk', value: string }

type Prefix__DARKLUA_TYPE_am = PrefixEnum__DARKLUA_TYPE_al & {
    len: (self: Prefix__DARKLUA_TYPE_am) -> number,
    isVerbatim: (self: Prefix__DARKLUA_TYPE_am) -> boolean,
    isDrive: (self: Prefix__DARKLUA_TYPE_am) -> boolean,
    hasImplicitRoot: (self: Prefix__DARKLUA_TYPE_am) -> boolean,

    clone: (self: Prefix__DARKLUA_TYPE_am) -> Prefix__DARKLUA_TYPE_am,
    equal: (self: Prefix__DARKLUA_TYPE_am, other: Prefix__DARKLUA_TYPE_am) -> boolean,
}

type PrefixStatic__DARKLUA_TYPE_an = Prefix__DARKLUA_TYPE_am & {
    Verbatim: (value: string) -> Prefix__DARKLUA_TYPE_am,
    VerbatimUNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_am,
    VerbatimDisk: (value: string) -> Prefix__DARKLUA_TYPE_am,
    DeviceNS: (value: string) -> Prefix__DARKLUA_TYPE_am,
    UNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_am,
    Disk: (value: string) -> Prefix__DARKLUA_TYPE_am,
}

type Prefix__DARKLUA_TYPE_ao = Prefix__DARKLUA_TYPE_am
type PrefixComponent__DARKLUA_TYPE_ap = {
    type: 'prefix',
    raw: string,
    parsed: Prefix__DARKLUA_TYPE_ao,
}

type NormalComponent__DARKLUA_TYPE_aq = { type: 'normal', value: string }

type ComponentEnum__DARKLUA_TYPE_ar =
    NormalComponent__DARKLUA_TYPE_aq
    | { type: 'rootDir' }
    | { type: 'curDir' }
    | { type: 'parentDir' }
    | PrefixComponent__DARKLUA_TYPE_ap

type ComponentCommon__DARKLUA_TYPE_as = {
    toString: (self: Component__DARKLUA_TYPE_at) -> string,
    equal: (self: Component__DARKLUA_TYPE_at, other: Component__DARKLUA_TYPE_at) -> boolean,
}

type Component__DARKLUA_TYPE_at = ComponentEnum__DARKLUA_TYPE_ar & ComponentCommon__DARKLUA_TYPE_as

type ComponentStatic__DARKLUA_TYPE_au = Component__DARKLUA_TYPE_at & {
    normal: (value: string) -> Component__DARKLUA_TYPE_at,
    rootDir: () -> Component__DARKLUA_TYPE_at,
    curDir: () -> Component__DARKLUA_TYPE_at,
    parentDir: () -> Component__DARKLUA_TYPE_at,
    prefix: (raw: string, prefix: Prefix__DARKLUA_TYPE_ao) -> Component__DARKLUA_TYPE_at,
}

type Rev__DARKLUA_TYPE_av<T> = {
    next: (self: Rev__DARKLUA_TYPE_av<T>) -> T?,
    collect: (self: Rev__DARKLUA_TYPE_av<T>) -> { T },
    rev: (self: Rev__DARKLUA_TYPE_av<T>) -> Rev__DARKLUA_TYPE_av<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev__DARKLUA_TYPE_av<T>) -> T?,

    clone: (self: Rev__DARKLUA_TYPE_av<T>) -> Rev__DARKLUA_TYPE_av<T>,
}

type DoubleEndedIterator__DARKLUA_TYPE_aw<T> = {
    next: (self: DoubleEndedIterator__DARKLUA_TYPE_aw<T>) -> T?,
    nextBack: (self: DoubleEndedIterator__DARKLUA_TYPE_aw<T>) -> T?,

    clone: (self: DoubleEndedIterator__DARKLUA_TYPE_aw<T>) -> DoubleEndedIterator__DARKLUA_TYPE_aw<T>,
}

type Private__DARKLUA_TYPE_ax<T> = {
    _iter: DoubleEndedIterator__DARKLUA_TYPE_aw<T>,
}

type PrivateRev__DARKLUA_TYPE_ay<T> = Rev__DARKLUA_TYPE_av<T> & Private__DARKLUA_TYPE_ax<T>

type RevStatic__DARKLUA_TYPE_az = {
    new: <T>(iter: DoubleEndedIterator__DARKLUA_TYPE_aw<T>) -> Rev__DARKLUA_TYPE_av<T>,

    next: <T>(self: Rev__DARKLUA_TYPE_av<T>) -> T?,
    collect: <T>(self: Rev__DARKLUA_TYPE_av<T>) -> { T },
    rev: <T>(self: Rev__DARKLUA_TYPE_av<T>) -> Rev__DARKLUA_TYPE_av<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev__DARKLUA_TYPE_av<T>) -> T?,

    clone: <T>(self: Rev__DARKLUA_TYPE_av<T>) -> Rev__DARKLUA_TYPE_av<T>,
}

type Component__DARKLUA_TYPE_aA = Component__DARKLUA_TYPE_at
type Prefix__DARKLUA_TYPE_aB = Prefix__DARKLUA_TYPE_am
type Rev__DARKLUA_TYPE_aC<T> = Rev__DARKLUA_TYPE_av<T>

type char__DARKLUA_TYPE_aD = string

type Components__DARKLUA_TYPE_aE = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix__DARKLUA_TYPE_aB?,

    prefixLen: (self: Components__DARKLUA_TYPE_aE) -> number,
    prefixVerbatim: (self: Components__DARKLUA_TYPE_aE) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components__DARKLUA_TYPE_aE) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components__DARKLUA_TYPE_aE) -> number,
    -- is the iteration complete?
    finished: (self: Components__DARKLUA_TYPE_aE) -> boolean,
    isSepByte: (self: Components__DARKLUA_TYPE_aE, b: char__DARKLUA_TYPE_aD) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components__DARKLUA_TYPE_aE) -> string,
    hasRoot: (self: Components__DARKLUA_TYPE_aE) -> boolean,
    includeCurDir: (self: Components__DARKLUA_TYPE_aE) -> boolean,
    parseSingleComponent: (self: Components__DARKLUA_TYPE_aE, comp: string) -> Component__DARKLUA_TYPE_aA?,
    parseNextComponent: (self: Components__DARKLUA_TYPE_aE) -> (number, Component__DARKLUA_TYPE_aA?),
    parseNextComponentBack: (self: Components__DARKLUA_TYPE_aE) -> (number, Component__DARKLUA_TYPE_aA?),
    trimLeft: (self: Components__DARKLUA_TYPE_aE) -> (),
    trimRight: (self: Components__DARKLUA_TYPE_aE) -> (),

    -- Iterator
    next: (self: Components__DARKLUA_TYPE_aE) -> Component__DARKLUA_TYPE_aA?,
    collect: (self: Components__DARKLUA_TYPE_aE) -> { Component__DARKLUA_TYPE_aA },
    rev: (self: Components__DARKLUA_TYPE_aE) -> Rev__DARKLUA_TYPE_aC<Component__DARKLUA_TYPE_aA>,
    -- DoubleEndedIterator
    nextBack: (self: Components__DARKLUA_TYPE_aE) -> Component__DARKLUA_TYPE_aA?,

    -- Clone
    clone: (self: Components__DARKLUA_TYPE_aE) -> Components__DARKLUA_TYPE_aE,
    equal: (self: Components__DARKLUA_TYPE_aE, other: Components__DARKLUA_TYPE_aE) -> boolean,
}

type IterComponents__DARKLUA_TYPE_aF = (items: { Component__DARKLUA_TYPE_aA }, index: number?) -> (number?, Component__DARKLUA_TYPE_aA)

type State__DARKLUA_TYPE_aG = 'Prefix' | 'StartDir' | 'Body' | 'Done'

type Component__DARKLUA_TYPE_aH = Component__DARKLUA_TYPE_at
type Components__DARKLUA_TYPE_aI = Components__DARKLUA_TYPE_aE
type Prefix__DARKLUA_TYPE_aJ = Prefix__DARKLUA_TYPE_am
type Ancestors__DARKLUA_TYPE_aK = {
    -- Iterator
    next: (self: Ancestors__DARKLUA_TYPE_aK) -> Path__DARKLUA_TYPE_aM?,
    collect: (self: Ancestors__DARKLUA_TYPE_aK) -> { Path__DARKLUA_TYPE_aM },
}

type AsPath__DARKLUA_TYPE_aL = string | Path__DARKLUA_TYPE_aM | Components__DARKLUA_TYPE_aI

type Path__DARKLUA_TYPE_aM = {
    toString: (self: Path__DARKLUA_TYPE_aM) -> string,

    toPathBuf: (self: Path__DARKLUA_TYPE_aM) -> Path__DARKLUA_TYPE_aM,
    isAbsolute: (self: Path__DARKLUA_TYPE_aM) -> boolean,
    isRelative: (self: Path__DARKLUA_TYPE_aM) -> boolean,
    hasRoot: (self: Path__DARKLUA_TYPE_aM) -> boolean,
    parent: (self: Path__DARKLUA_TYPE_aM) -> Path__DARKLUA_TYPE_aM?,
    ancestors: (self: Path__DARKLUA_TYPE_aM) -> Ancestors__DARKLUA_TYPE_aK,
    fileName: (self: Path__DARKLUA_TYPE_aM) -> string?,
    stripPrefix: (self: Path__DARKLUA_TYPE_aM, base: AsPath__DARKLUA_TYPE_aL) -> Path__DARKLUA_TYPE_aM?,
    startsWith: (self: Path__DARKLUA_TYPE_aM, base: AsPath__DARKLUA_TYPE_aL) -> boolean,
    endsWith: (self: Path__DARKLUA_TYPE_aM, child: AsPath__DARKLUA_TYPE_aL) -> boolean,

    fileStem: (self: Path__DARKLUA_TYPE_aM) -> string?,
    filePrefix: (self: Path__DARKLUA_TYPE_aM) -> string?,
    extension: (self: Path__DARKLUA_TYPE_aM) -> string?,
    join: (self: Path__DARKLUA_TYPE_aM, path: AsPath__DARKLUA_TYPE_aL) -> Path__DARKLUA_TYPE_aM,

    withFileName: (self: Path__DARKLUA_TYPE_aM, fileName: string) -> Path__DARKLUA_TYPE_aM,
    withExtension: (self: Path__DARKLUA_TYPE_aM, extension: string) -> Path__DARKLUA_TYPE_aM,
    components: (self: Path__DARKLUA_TYPE_aM) -> Components__DARKLUA_TYPE_aI,

    equal: (self: Path__DARKLUA_TYPE_aM, other: Path__DARKLUA_TYPE_aM) -> boolean,

    -- PathBuf
    push: (self: Path__DARKLUA_TYPE_aM, path: AsPath__DARKLUA_TYPE_aL) -> (),
    pop: (self: Path__DARKLUA_TYPE_aM) -> boolean,
    setFileName: (self: Path__DARKLUA_TYPE_aM, fileName: string) -> (),
    setExtension: (self: Path__DARKLUA_TYPE_aM, extension: string) -> boolean,
    clear: (self: Path__DARKLUA_TYPE_aM) -> (),
}

type Path__DARKLUA_TYPE_aN = Path__DARKLUA_TYPE_aM
type AsPath__DARKLUA_TYPE_aO = AsPath__DARKLUA_TYPE_aL
type Component__DARKLUA_TYPE_aP = ComponentStatic__DARKLUA_TYPE_au
type Path__DARKLUA_TYPE_aQ = Path__DARKLUA_TYPE_aN
type AsPath__DARKLUA_TYPE_aR = AsPath__DARKLUA_TYPE_aO
type Path__DARKLUA_TYPE_aS  = Path__DARKLUA_TYPE_aQ
type AsPath__DARKLUA_TYPE_aT  = AsPath__DARKLUA_TYPE_aR
type Range__DARKLUA_TYPE_aU = { min: number?, minExclusive: boolean, max: number?, maxExclusive: boolean }

type RangeIn__DARKLUA_TYPE_aV = { min: number?, minExclusive: boolean?, max: number?, maxExclusive: boolean? }

type RangeInput__DARKLUA_TYPE_aW = string | number | RangeIn__DARKLUA_TYPE_aV

type Cause__DARKLUA_TYPE_aX = {
	ok: boolean,

	encompassingType: Type__DARKLUA_TYPE_a1?,

	errs: {
		{
			type: Type__DARKLUA_TYPE_a1,
			input: any?,
			message: string?,
		}
	},

	formatErr: (_self: any?) -> string,
}

type CauseMt__DARKLUA_TYPE_aY = {
	__tostring: (self: any) -> string,
}

type Packed__DARKLUA_TYPE_aZ = { n: number, [number]: any }

type TypeMt__DARKLUA_TYPE_a_ = {
	__index: {
		matches: (self: any,...any) -> (boolean, Cause__DARKLUA_TYPE_aX),
		assert: (self: any,...any) -> ...any,

		format: (self: any) -> string,
		formatErr: (self: any, cause: any, values: Packed__DARKLUA_TYPE_aZ?) -> string,
	},

	__call: (self: any,...any) -> (boolean, string?),

	__tostring: (self: any) -> string,
}

type TypeRaw__DARKLUA_TYPE_a0 = {
	kind: string,

	meta: {
		[string]: any,
	}?,

	_matches: (...any) -> Cause__DARKLUA_TYPE_aX,
	_format: (highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any }) -> string,

	_needsParens: boolean?,

	basic: {
		typeof: string?,
		type: string?,
	}?,

	any: {
		allowNil: boolean?,
	}?,

	unknown: {
		allowNil: boolean?,
	}?,

	custom: {
		type: Type__DARKLUA_TYPE_a1?,
		name: string,
		typechecker: (any) -> (boolean, any?),
	}?,

	number: {
		range: Range__DARKLUA_TYPE_aU?,
		integer: boolean?,
	}?,

	string: {
		pattern: string?,
		bytes: Range__DARKLUA_TYPE_aU?,
		graphemes: Range__DARKLUA_TYPE_aU?,
		unicode: boolean?,
	}?,

	thread: {
		status: { [CoroutineStatus__DARKLUA_TYPE_a2]: boolean }?,
	}?,

	instanceIsA: {
		class: string,
	}?,

	literal: {
		value: any,
	}?,

	tuple: {
		contents: { Type__DARKLUA_TYPE_a1 },
		vararg: Type__DARKLUA_TYPE_a1?,
	}?,

	vararg: {
		type: Type__DARKLUA_TYPE_a1,
		length: Range__DARKLUA_TYPE_aU?,
	}?,

	fn: {
		args: Type__DARKLUA_TYPE_a1,
		returns: Type__DARKLUA_TYPE_a1,
	}?,

	table: {
		contents: { [string]: Type__DARKLUA_TYPE_a1 },
		indexer: { key: Type__DARKLUA_TYPE_a1, value: Type__DARKLUA_TYPE_a1 }?,

		array: boolean?,
		count: Range__DARKLUA_TYPE_aU?,
		raw: boolean?,
	}?,

	intersection: {
		contents: { Type__DARKLUA_TYPE_a1 },
	}?,
	union: {
		contents: { Type__DARKLUA_TYPE_a1 },
		optional: boolean?,
	}?,
}

type Type__DARKLUA_TYPE_a1 = typeof(setmetatable({} :: TypeRaw__DARKLUA_TYPE_a0, {} :: TypeMt__DARKLUA_TYPE_a_))

type CoroutineStatus__DARKLUA_TYPE_a2 = "dead" | "normal" | "running" | "suspended"

type TuplePacked__DARKLUA_TYPE_a3<T...> = () -> T...

type UnionType__DARKLUA_TYPE_a4 =
	(<T1, T2>(T1, T2) -> T1 | T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 | T2 | T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 | T2 | T3 | T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 | T2 | T3 | T4 | T5)
	& (<T>(...T) -> T)

type IntersectionType__DARKLUA_TYPE_a5 =
	(<T1, T2>(T1, T2) -> T1 & T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 & T2 & T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 & T2 & T3 & T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 & T2 & T3 & T4 & T5)
	& (<T>(...T) -> T)

type BuiltType__DARKLUA_TYPE_a6<T...= ...any> = Type__DARKLUA_TYPE_a1 & { __getType: () -> T...} & typeof(BuiltType)

type Cause__DARKLUA_TYPE_a7 = Cause__DARKLUA_TYPE_aX
type Type__DARKLUA_TYPE_a8 = Type__DARKLUA_TYPE_a1
type TuplePacked__DARKLUA_TYPE_a9<T...> = TuplePacked__DARKLUA_TYPE_a3<T...>

type Cause__DARKLUA_TYPE_ba  = Cause__DARKLUA_TYPE_a7
type Type__DARKLUA_TYPE_bb  = Type__DARKLUA_TYPE_a8
type TuplePacked__DARKLUA_TYPE_bc<T...> = TuplePacked__DARKLUA_TYPE_a9<T...>

type Components__DARKLUA_TYPE_bd = typeof(Path.new(""):components())

type Component__DARKLUA_TYPE_be = typeof(Path.new(""):components():collect()[1])

type Contents__DARKLUA_TYPE_bf = typeof(ContentsType:type())

type Component__DARKLUA_TYPE_bg = Component__DARKLUA_TYPE_be
type Components__DARKLUA_TYPE_bh = Components__DARKLUA_TYPE_bd
type AsPath__DARKLUA_TYPE_bi = AsPath__DARKLUA_TYPE_aT
type Path__DARKLUA_TYPE_bj = Path__DARKLUA_TYPE_aS
type PeekableComponents__DARKLUA_TYPE_bk = typeof(setmetatable(
	{} :: {
		iter: Components__DARKLUA_TYPE_bh,
		peeked: Component__DARKLUA_TYPE_bg | false,
	},
	{} :: PeekableComponentsImpl__DARKLUA_TYPE_bl
))

type PeekableComponentsImpl__DARKLUA_TYPE_bl = {
	__index: PeekableComponentsImpl__DARKLUA_TYPE_bl,
	peek: (self: PeekableComponents__DARKLUA_TYPE_bk) -> Component__DARKLUA_TYPE_bg?,
	next: (self: PeekableComponents__DARKLUA_TYPE_bk) -> Component__DARKLUA_TYPE_bg?,
}

type Path__DARKLUA_TYPE_bm = Path__DARKLUA_TYPE_aS
type AsPath__DARKLUA_TYPE_bn = AsPath__DARKLUA_TYPE_aT
type DirectoryPath__DARKLUA_TYPE_bo = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: DirectoryPathImpl__DARKLUA_TYPE_bp
))

type DirectoryPathImpl__DARKLUA_TYPE_bp = {
	__index: DirectoryPathImpl__DARKLUA_TYPE_bp,
	__tostring: (self: DirectoryPath__DARKLUA_TYPE_bo) -> string,
	new: (dirPath: typeof(AsPathType:type())) -> DirectoryPath__DARKLUA_TYPE_bo,
	fromExisting: (dirPath: typeof(AsPathType:type())) -> DirectoryPath__DARKLUA_TYPE_bo,
	withDirWritten: (self: DirectoryPath__DARKLUA_TYPE_bo, allowOverwrite: typeof(optionalBooleanType:type())) -> DirectoryPath__DARKLUA_TYPE_bo,
	is: (value: any) -> boolean,
	isDir: (self: DirectoryPath__DARKLUA_TYPE_bo) -> typeof(booleanType:type()),
	readDir: (self: DirectoryPath__DARKLUA_TYPE_bo) -> typeof(arrayOfStringType:type()),
	writeDir: (self: DirectoryPath__DARKLUA_TYPE_bo) -> (),
	removeDir: (self: DirectoryPath__DARKLUA_TYPE_bo) -> (),
}

type FilePath__DARKLUA_TYPE_bq = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: FilePathImpl__DARKLUA_TYPE_br)
)

type FilePathImpl__DARKLUA_TYPE_br = {
	__index: FilePathImpl__DARKLUA_TYPE_br,
	__tostring: (self: FilePath__DARKLUA_TYPE_bq) -> string,
	new: (filePath: typeof(AsPathType:type())) -> FilePath__DARKLUA_TYPE_bq,
	fromExisting: (filePath: typeof(AsPathType:type())) -> FilePath__DARKLUA_TYPE_bq,
	withFileWritten: (
		self: FilePath__DARKLUA_TYPE_bq,
		contents: typeof(ContentsType:type()),
		allowOverwrite: typeof(optionalBooleanType:type())
	) -> FilePath__DARKLUA_TYPE_bq,
	is: (value: any) -> boolean,
	isFile: (self: FilePath__DARKLUA_TYPE_bq) -> typeof(booleanType:type()),
	readFile: (self: FilePath__DARKLUA_TYPE_bq) -> typeof(stringType:type()),
	writeFile: (self: FilePath__DARKLUA_TYPE_bq, contents: typeof(ContentsType:type())) -> (),
	removeFile: (self: FilePath__DARKLUA_TYPE_bq) -> (),
}

type DirectoryPath__DARKLUA_TYPE_bs = DirectoryPath__DARKLUA_TYPE_bo
type FilePath__DARKLUA_TYPE_bt = FilePath__DARKLUA_TYPE_bq
type Metadata__DARKLUA_TYPE_bu = luneFileSystem.Metadata

type MetadataKind__DARKLUA_TYPE_bv = luneFileSystem.MetadataKind

type MetadataPermissions__DARKLUA_TYPE_bw = luneFileSystem.MetadataPermissions

type WriteOptions__DARKLUA_TYPE_bx = luneFileSystem.WriteOptions

type Components__DARKLUA_TYPE_by = Components__DARKLUA_TYPE_bd
type Path__DARKLUA_TYPE_bz = Path__DARKLUA_TYPE_aS
type AsPath__DARKLUA_TYPE_bA = AsPath__DARKLUA_TYPE_aT
type Component__DARKLUA_TYPE_bB = Component__DARKLUA_TYPE_be
type DirEntry__DARKLUA_TYPE_bC = {
	name: string,
	file: FilePath__DARKLUA_TYPE_bt?,
	dir: DirectoryPath__DARKLUA_TYPE_bs?,
	path: Path__DARKLUA_TYPE_bz,
}

type ObserveState__DARKLUA_TYPE_bD = "__inflight__" | "__dead__"

type EntryValue__DARKLUA_TYPE_bE = {
	stateOrCleanup: ObserveState__DARKLUA_TYPE_bD | (() -> ())?,
	entry: DirEntry__DARKLUA_TYPE_bC,
}

type DirectoryPath__DARKLUA_TYPE_bF  = DirectoryPath__DARKLUA_TYPE_bs
type FilePath__DARKLUA_TYPE_bG  = FilePath__DARKLUA_TYPE_bt
type Metadata__DARKLUA_TYPE_bH  = Metadata__DARKLUA_TYPE_bu
type MetadataKind__DARKLUA_TYPE_bI  = MetadataKind__DARKLUA_TYPE_bv
type MetadataPermissions__DARKLUA_TYPE_bJ  = MetadataPermissions__DARKLUA_TYPE_bw
type WriteOptions__DARKLUA_TYPE_bK  = WriteOptions__DARKLUA_TYPE_bx
type Components__DARKLUA_TYPE_bL  = Components__DARKLUA_TYPE_by
type Path__DARKLUA_TYPE_bM  = Path__DARKLUA_TYPE_bz
type AsPath__DARKLUA_TYPE_bN  = AsPath__DARKLUA_TYPE_bA
type Component__DARKLUA_TYPE_bO  = Component__DARKLUA_TYPE_bB
type DirEntry__DARKLUA_TYPE_bP  = DirEntry__DARKLUA_TYPE_bC local __DARKLUA_BUNDLE_MODULES={cache={}::any}do do local function __modImpl()


return nil
end function __DARKLUA_BUNDLE_MODULES.a():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a=v end return v.c end end do local function __modImpl()
local function all<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if not predicate(element, index) then
            return false
        end
    end
    return true
end

return all
end function __DARKLUA_BUNDLE_MODULES.b():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.b if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.b=v end return v.c end end do local function __modImpl()
local function reduce<T, A>(
    array: { T },
    reducer: (accumulator: A, value: T, index: number) -> A,
    accumulator: A?
): A
    if accumulator == nil then
        for index, value in array do
            if index == 1 then
                accumulator = value :: any
            else
                accumulator = reducer(accumulator :: A, value, index)
            end
        end
    else
        for index, value in array do
            accumulator = reducer(accumulator, value, index)
        end
    end
    return accumulator :: A
end











return (reduce :: any) :: reduceFromFirstValue__DARKLUA_TYPE_b & reduceWithAccumulator__DARKLUA_TYPE_c
end function __DARKLUA_BUNDLE_MODULES.c():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.c if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.c=v end return v.c end end do local function __modImpl()
local reduce = __DARKLUA_BUNDLE_MODULES.c()

local function alternate<T, U>(array: { T }, ...: { U }): { any }
    local alternateWith = { ... }

    if #alternateWith == 0 then
        return array
    end

    local minimumLength = reduce(alternateWith, function(minimum: number, value)
        return math.min(minimum, #value)
    end, #array)

    if minimumLength == 0 then
        return {}
    end

    local result = {}

    for i = 1, minimumLength do
        table.insert(result, array[i])
        for _, otherArray in alternateWith do
            table.insert(result, otherArray[i] :: any)
        end
    end

    return result
end






return (alternate :: any) :: alternate1__DARKLUA_TYPE_d & alternate2__DARKLUA_TYPE_e & alternate3__DARKLUA_TYPE_f & alternateAll__DARKLUA_TYPE_g
end function __DARKLUA_BUNDLE_MODULES.d():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.d if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.d=v end return v.c end end do local function __modImpl()
local function any<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if predicate(element, index) then
            return true
        end
    end
    return false
end

return any
end function __DARKLUA_BUNDLE_MODULES.e():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.e if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.e=v end return v.c end end do local function __modImpl()
local function average(array: { number }): number?
    local length = #array
    if length == 0 then
        return nil
    end

    local result = 0

    for _, element in array do
        result += element
    end

    return result / length
end

return average
end function __DARKLUA_BUNDLE_MODULES.f():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.f if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.f=v end return v.c end end do local function __modImpl()
local function averageBy<T>(array: { T }, map: (T) -> number): number?
    local length = #array
    if length == 0 then
        return nil
    end

    local result = 0

    for _, element in array do
        result += map(element)
    end

    return result / length
end

return averageBy
end function __DARKLUA_BUNDLE_MODULES.g():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.g if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.g=v end return v.c end end do local function __modImpl()
local function concat<T>(array: { T }, ...: { T }?): { T }
    local result = nil

    for i = 1, select('#', ...) do
        local concatWith = select(i, ...)

        if concatWith ~= nil and #concatWith > 0 then
            result = result or table.clone(array)

            for _, element in concatWith do
                table.insert(result, element)
            end
        end
    end

    return result or array
end

return concat
end function __DARKLUA_BUNDLE_MODULES.h():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.h if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.h=v end return v.c end end do local function __modImpl()
local function contains<T>(array: { T }, element: T): boolean
    for _, value in array do
        if value == element then
            return true
        end
    end
    return false
end

return contains
end function __DARKLUA_BUNDLE_MODULES.i():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.i if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.i=v end return v.c end end do local function __modImpl()
return table.clone
end function __DARKLUA_BUNDLE_MODULES.j():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.j if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.j=v end return v.c end end do local function __modImpl()
local function deduplicate<T>(array: { T }): { T }
    if #array == 0 then
        return array
    end

    local removeIndexes = {}

    local seenSet = {}

    for index, element in array do
        if seenSet[element] == nil then
            seenSet[element] = true
        else
            table.insert(removeIndexes, index)
        end
    end

    local totalIndexes = #removeIndexes
    if totalIndexes == 0 then
        return array
    else
        local result = table.clone(array)
        for i = totalIndexes, 1, -1 do
            table.remove(result, removeIndexes[i])
        end
        return result
    end
end

return deduplicate
end function __DARKLUA_BUNDLE_MODULES.k():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.k if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.k=v end return v.c end end do local function __modImpl()
local function deduplicateByKey<T, Comparable>(array: { T }, key: (T) -> Comparable): { T }
    local removeIndexes = {}

    local seenSet = {}

    for index, element in array do
        local elementKey = key(element)
        if seenSet[elementKey] == nil then
            seenSet[elementKey] = true
        else
            table.insert(removeIndexes, index)
        end
    end

    local totalIndexes = #removeIndexes
    if totalIndexes == 0 then
        return array
    else
        local result = table.clone(array)
        for i = totalIndexes, 1, -1 do
            table.remove(result, removeIndexes[i])
        end
        return result
    end
end

return deduplicateByKey
end function __DARKLUA_BUNDLE_MODULES.l():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.l if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.l=v end return v.c end end do local function __modImpl()
local function filter<T>(array: { T }, predicate: (T, number) -> boolean): { T }
    local new = {}
    for i, element in array do
        if predicate(element, i) then
            table.insert(new, element)
        end
    end
    return new
end

return filter
end function __DARKLUA_BUNDLE_MODULES.m():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.m if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.m=v end return v.c end end do local function __modImpl()
local function find<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): T?
    if start == nil or start == 1 then
        for index, element in array do
            if predicate(element, index) then
                return element
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            if predicate(element, i) then
                return element
            end
        end
    end

    return nil
end

return find
end function __DARKLUA_BUNDLE_MODULES.n():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.n if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.n=v end return v.c end end do local function __modImpl()
local function findIndex<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): number?
    if start == nil or start == 1 then
        for index, element in array do
            if predicate(element, index) then
                return index
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            if predicate(element, i) then
                return i
            end
        end
    end

    return nil
end

return findIndex
end function __DARKLUA_BUNDLE_MODULES.o():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.o if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.o=v end return v.c end end do local function __modImpl()
local function findIndexByValue<T>(array: { T }, element: T, start: number?): number?
    return table.find(array, element, start)
end

return findIndexByValue
end function __DARKLUA_BUNDLE_MODULES.p():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.p if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.p=v end return v.c end end do local function __modImpl()
local function findMap<T, U>(array: { T }, mapFn: (element: T, index: number) -> U?, start: number?): U?
    if start == nil or start == 1 then
        for index, element in array do
            local result = mapFn(element, index)
            if result ~= nil then
                return result
            end
        end
    else
        local length = #array
        for i = start, length do
            local element = array[i]
            local result = mapFn(element, i)
            if result ~= nil then
                return result
            end
        end
    end

    return nil
end

return findMap
end function __DARKLUA_BUNDLE_MODULES.q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.q=v end return v.c end end do local function __modImpl()
local function isArray(value: unknown): boolean
    if type(value) ~= 'table' then
        return false
    end

    local tableValue: { [any]: any } = value :: any

    if next(tableValue) == nil then
        -- an empty table is an empty array
        return true
    end

    local length = #tableValue

    if length == 0 then
        return false
    end

    local expectIndex = 0

    for key in tableValue do
        expectIndex += 1
        if type(key) ~= 'number' or key ~= expectIndex then
            return false
        end
    end

    return length == expectIndex
end

return isArray
end function __DARKLUA_BUNDLE_MODULES.r():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.r if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.r=v end return v.c end end do local function __modImpl()
local isArray = __DARKLUA_BUNDLE_MODULES.r()

local function flatMap<T, U>(array: { T }, mapFn: (T, number) -> nil | U | { U }): { U }
    local new = {}
    for i, element in array do
        local value = mapFn(element, i)
        if value ~= nil then
            if isArray(value) then
                for _, innerElement in value :: { U } do
                    table.insert(new, innerElement)
                end
            else
                table.insert(new, value :: U)
            end
        end
    end
    return new
end

return flatMap
end function __DARKLUA_BUNDLE_MODULES.s():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.s if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.s=v end return v.c end end do local function __modImpl()
local isArray = __DARKLUA_BUNDLE_MODULES.r()

local function flatten<T>(array: { T | { T } }, depth: number?): { T }
    local actualDepth = if depth == nil then math.huge else depth
    if actualDepth == 0 then
        return array :: { T }
    end

    local new = {}

    for _, element in array do
        if isArray(element) then
            local iter: { T } = if actualDepth > 1
                then flatten(element :: { T })
                else element :: { T }
            for _, innerElement in iter do
                table.insert(new, innerElement)
            end
        else
            table.insert(new, element :: T)
        end
    end

    return new
end

return flatten
end function __DARKLUA_BUNDLE_MODULES.t():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.t if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.t=v end return v.c end end do local function __modImpl()
local function fromFn<T>(generator: (number) -> T?): { T }
    local array = {}

    local i = 1
    while true do
        local element = generator(i)
        if element == nil then
            break
        else
            i += 1
            table.insert(array, element)
        end
    end

    return array
end

return fromFn
end function __DARKLUA_BUNDLE_MODULES.u():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.u if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.u=v end return v.c end end do local function __modImpl()
local function fromTryFn<T>(generator: (number) -> T?): { T }
    local array = {}

    local i = 1
    while true do
        local success, element = pcall(generator, i)
        if success == false or element == nil then
            break
        else
            i += 1
            table.insert(array, element)
        end
    end

    return array
end

return fromTryFn
end function __DARKLUA_BUNDLE_MODULES.v():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.v if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.v=v end return v.c end end do local function __modImpl()
local function isEmpty(value: { [any]: any }): boolean
    return next(value) == nil
end

return isEmpty
end function __DARKLUA_BUNDLE_MODULES.w():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.w if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.w=v end return v.c end end do local function __modImpl()
local function map<T, U>(array: { T }, mapFn: (T, number) -> U?): { U }
    local new = {}
    for i, element in array do
        local value = mapFn(element, i)
        if value ~= nil then
            table.insert(new, value)
        end
    end
    return new
end

return map
end function __DARKLUA_BUNDLE_MODULES.x():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.x if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.x=v end return v.c end end do local function __modImpl()
local function maximum(array: { number }, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.maximum when the array is empty')
        end
        initialValue = array[1]
    end

    local accumulator = initialValue :: number
    for _, element in array do
        accumulator = math.max(accumulator, element)
    end
    return accumulator
end

return maximum
end function __DARKLUA_BUNDLE_MODULES.y():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.y if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.y=v end return v.c end end do local function __modImpl()
local function maximumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.maximumBy when the array is empty')
        end
        initialValue = map(array[1])
    end

    local accumulator: number = initialValue :: number
    for _, element in array do
        accumulator = math.max(accumulator, map(element))
    end
    return accumulator
end

return maximumBy
end function __DARKLUA_BUNDLE_MODULES.z():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.z if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.z=v end return v.c end end do local function __modImpl()
local function minimum(array: { number }, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.minimum when the array is empty')
        end
        initialValue = array[1]
    end

    local accumulator = initialValue :: number
    for _, element in array do
        accumulator = math.min(accumulator, element)
    end
    return accumulator
end

return minimum
end function __DARKLUA_BUNDLE_MODULES.A():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.A if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.A=v end return v.c end end do local function __modImpl()
local function minimumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    if initialValue == nil then
        if #array == 0 then
            error('initial value must be provided to Array.minimumBy when the array is empty')
        end
        initialValue = map(array[1])
    end

    local accumulator: number = initialValue :: number
    for _, element in array do
        accumulator = math.min(accumulator, map(element))
    end
    return accumulator
end

return minimumBy
end function __DARKLUA_BUNDLE_MODULES.B():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.B if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.B=v end return v.c end end do local function __modImpl()
local function partition<T>(array: { T }, predicate: (T, number) -> boolean): ({ T }, { T })
    local trueValues = {}
    local falseValues = {}
    for i, element in array do
        if predicate(element, i) then
            table.insert(trueValues, element)
        else
            table.insert(falseValues, element)
        end
    end
    return trueValues, falseValues
end

return partition
end function __DARKLUA_BUNDLE_MODULES.C():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.C if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.C=v end return v.c end end do local function __modImpl()
local function pop<T>(array: { T }, count: number?): { T }
    local actualCount = count or 1

    if actualCount == 1 then
        local new = table.clone(array)
        table.remove(new)
        return new
    elseif actualCount == 0 then
        return array
    else
        local length = #array

        local remaining = length - actualCount

        if remaining <= 0 then
            return {}
        elseif remaining > actualCount then
            local new = table.clone(array)

            for _ = 1, actualCount do
                table.remove(new)
            end

            return new
        else
            local new = {}

            for i = 1, remaining do
                new[i] = array[i]
            end
            return new
        end
    end
end

return pop
end function __DARKLUA_BUNDLE_MODULES.D():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.D if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.D=v end return v.c end end do local function __modImpl()
local function popFirst<T>(array: { T }, count: number?): { T }
    local actualCount = count or 1

    if actualCount == 1 then
        local new = table.clone(array)
        table.remove(new, 1)
        return new
    elseif actualCount == 0 then
        return array
    else
        local length = #array

        local remaining = length - actualCount

        if remaining <= 0 then
            return {}
        elseif remaining > actualCount then
            local new = table.clone(array)

            for _ = 1, actualCount do
                table.remove(new, 1)
            end

            return new
        else
            local new = {}

            for i = 1 + actualCount, length do
                table.insert(new, array[i])
            end

            return new
        end
    end
end

return popFirst
end function __DARKLUA_BUNDLE_MODULES.E():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.E if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.E=v end return v.c end end do local function __modImpl()
local function product(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 1 else initialValue

    for _, element in array do
        result *= element
    end

    return result
end

return product
end function __DARKLUA_BUNDLE_MODULES.F():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.F if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.F=v end return v.c end end do local function __modImpl()
local function productBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    local result = if initialValue == nil then 1 else initialValue

    for _, element in array do
        result *= map(element)
    end

    return result
end

return productBy
end function __DARKLUA_BUNDLE_MODULES.G():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.G if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.G=v end return v.c end end do local function __modImpl()
local function push<T>(array: { T }, ...: T?): { T }
    local newArray = table.clone(array)

    for i = 1, select('#', ...) do
        local element = select(i, ...)
        if element ~= nil then
            table.insert(newArray, element)
        end
    end

    return newArray
end

return push
end function __DARKLUA_BUNDLE_MODULES.H():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.H if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.H=v end return v.c end end do local function __modImpl()
local function range<T>(array: { T }, from: number, to: number?): { T }
    local length = #array
    if length == 0 then
        return array
    end
    local actualTo = if to == nil then length else to

    local normalizedFrom = if from < 0 then 1 + (from + length) else from
    local normalizedTo = if actualTo < 0 then 1 + (actualTo + length) else actualTo

    local result = {}

    if normalizedTo >= normalizedFrom then
        for i = math.max(normalizedFrom, 1), math.min(normalizedTo, length) do
            table.insert(result, array[i])
        end
    else
        for i = math.min(normalizedFrom, length), math.max(normalizedTo, 1), -1 do
            table.insert(result, array[i])
        end
    end

    return result
end

return range
end function __DARKLUA_BUNDLE_MODULES.I():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.I if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.I=v end return v.c end end do local function __modImpl()
local function removeSortedIndexes<T>(array: { T }, indexes: { number }): { T }
    local removeLength = #indexes
    local arrayLenth = #array

    if removeLength == 0 or arrayLenth == 0 then
        return array
    end

    local startFrom = nil
    for i = removeLength, 1, -1 do
        local index = indexes[i]
        if index <= arrayLenth then
            startFrom = index
            break
        end
    end

    if startFrom == nil then
        return array
    else
        local cloned = table.clone(array)
        local length = arrayLenth

        local previous = nil
        for i = startFrom, 1, -1 do
            local index = indexes[i]
            if index ~= previous and index <= length then
                length -= 1
                table.remove(cloned, index)
                previous = index
            end
        end

        return cloned
    end
end

return removeSortedIndexes
end function __DARKLUA_BUNDLE_MODULES.J():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.J if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.J=v end return v.c end end do local function __modImpl()
local function sort<T>(array: { T }, comparator: ((T, T) -> boolean)?): { T }
    if #array <= 1 then
        return array
    end
    local result = table.clone(array)
    table.sort(result, comparator)
    return result
end

return sort
end function __DARKLUA_BUNDLE_MODULES.K():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.K if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.K=v end return v.c end end do local function __modImpl()
local removeSortedIndexes = __DARKLUA_BUNDLE_MODULES.J()
local sort = __DARKLUA_BUNDLE_MODULES.K()

local function removeIndexes<T>(array: { T }, indexes: { number }): { T }
    local removeLength = #indexes
    local arrayLenth = #array

    if removeLength == 0 or arrayLenth == 0 then
        return array
    end

    local sortedIndexes = sort(indexes)

    return removeSortedIndexes(array, sortedIndexes)
end

return removeIndexes
end function __DARKLUA_BUNDLE_MODULES.L():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.L if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.L=v end return v.c end end do local function __modImpl()
local function removeValues<T>(array: { T }, ...: T?): { T }
    local removeLength = select('#', ...)
    local arrayLenth = #array

    if removeLength == 0 or arrayLenth == 0 then
        return array
    end

    local removeIndexes = {}
    for index, element in array do
        for i = 1, removeLength do
            local value: T? = select(i, ...)

            if value ~= nil and element == value then
                table.insert(removeIndexes, index)
            end
        end
    end

    local removeIndexesLength = #removeIndexes

    if removeIndexesLength == 0 then
        return array
    elseif removeIndexesLength == arrayLenth then
        return {}
    else
        local cloned = table.clone(array)

        for i = removeIndexesLength, 1, -1 do
            table.remove(cloned, removeIndexes[i])
        end

        return cloned
    end
end

return removeValues
end function __DARKLUA_BUNDLE_MODULES.M():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.M if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.M=v end return v.c end end do local function __modImpl()
local function reverse<T>(array: { T }): { T }
    local length = #array

    if length < 2 then
        return array
    end

    local newArray = table.clone(array)

    for i = 1, math.floor(length / 2) do
        local swapRight = length - i + 1

        newArray[i], newArray[swapRight] = newArray[swapRight], newArray[i]
    end

    return newArray
end

return reverse
end function __DARKLUA_BUNDLE_MODULES.N():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.N if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.N=v end return v.c end end do local function __modImpl()
local map = __DARKLUA_BUNDLE_MODULES.x()



local function sortByKey<T, Comparable>(array: { T }, key: (T) -> Comparable): { T }
    if #array <= 1 then
        return array
    end
    local result: { KeyElement__DARKLUA_TYPE_h<Comparable, T> } = map(array, function(element)
        return {
            key = key(element),
            element = element,
        }
    end)

    table.sort(result, function(a: any, b: any)
        return a.key < b.key
    end)

    for index, element in result do
        result[index] = element.element :: any
    end

    return result :: any
end

return sortByKey
end function __DARKLUA_BUNDLE_MODULES.O():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.O if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.O=v end return v.c end end do local function __modImpl()
local function stepBy<T>(array: { T }, step: number): { T }
    local length = #array

    if step == 1 then
        return array
    elseif step == -1 then
        local newArray = table.clone(array)

        for i = 1, math.floor(length / 2) do
            local swapRight = length - i + 1

            newArray[i], newArray[swapRight] = newArray[swapRight], newArray[i]
        end

        return newArray
    elseif step > 1 then
        local result = {}

        for i = 1, length, step do
            table.insert(result, array[i])
        end

        return result
    elseif step < -1 then
        local result = {}

        for i = length, 1, step do
            table.insert(result, array[i])
        end

        return result
    else
        error(`invalid step value '{step}' passed to Array.stepBy`)
    end
end

return stepBy
end function __DARKLUA_BUNDLE_MODULES.P():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.P if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.P=v end return v.c end end do local function __modImpl()
local function sum(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += element
    end

    return result
end

return sum
end function __DARKLUA_BUNDLE_MODULES.Q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Q=v end return v.c end end do local function __modImpl()
local function sumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += map(element)
    end

    return result
end

return sumBy
end function __DARKLUA_BUNDLE_MODULES.R():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.R if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.R=v end return v.c end end do local function __modImpl()
local function takeWhile<T>(
    array: { T },
    predicate: (element: T, index: number) -> boolean,
    start: number?
): { T }
    local arrayLength = #array

    if arrayLength == 0 then
        return array
    end

    local bound = arrayLength + 1
    local actualStart = if start == nil then 1 else start
    if actualStart == 1 then
        for index, element in array do
            if not predicate(element, index) then
                bound = index
                break
            end
        end
    else
        local length = #array
        for i = actualStart, length do
            local element = array[i]
            if not predicate(element, i) then
                bound = i
                break
            end
        end
    end

    if actualStart == bound then
        return {}
    elseif actualStart == 1 and bound > arrayLength then
        return array
    end

    local toInsert = bound - actualStart

    if actualStart == 1 and toInsert < arrayLength / 2 then
        local result = table.clone(array)

        for _ = 1, arrayLength - bound do
            table.remove(result)
        end

        return result
    else
        local result = {}

        for i = actualStart, bound - 1 do
            table.insert(result, array[i])
        end

        return result
    end
end

return takeWhile
end function __DARKLUA_BUNDLE_MODULES.S():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.S if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.S=v end return v.c end end do local function __modImpl()
local reduce = __DARKLUA_BUNDLE_MODULES.c()

local function zip<T>(array: { T }, ...: { T }): { { T } }
    local alternateWith = { ... }

    local minimumLength = reduce(alternateWith, function(minimum: number, value)
        return math.min(minimum, #value)
    end, #array)

    if minimumLength == 0 then
        return {}
    end

    local result = {}

    for i = 1, minimumLength do
        local entry = { array[i] }
        for _, otherArray in alternateWith do
            table.insert(entry, otherArray[i])
        end
        table.insert(result, entry)
    end

    return result
end






return (zip :: any) :: zip1__DARKLUA_TYPE_i & zip2__DARKLUA_TYPE_j & zip3__DARKLUA_TYPE_k & zipAll__DARKLUA_TYPE_l
end function __DARKLUA_BUNDLE_MODULES.T():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.T if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.T=v end return v.c end end do local function __modImpl()
return table.clone
end function __DARKLUA_BUNDLE_MODULES.U():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.U if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.U=v end return v.c end end do local function __modImpl()
local function count<K, V>(map: { [K]: V }): number
    local length = 0
    for _ in map do
        length += 1
    end
    return length
end

return count
end function __DARKLUA_BUNDLE_MODULES.V():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.V if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.V=v end return v.c end end do local function __modImpl()
local function entries<K, V>(map: { [K]: V }, keyIndex: any?, valueIndex: any?): { { [any]: K | V } }
    local useKeyIndex = if keyIndex == nil then 1 else keyIndex
    local useValueIndex = if valueIndex == nil then useKeyIndex + 1 else valueIndex

    local array = {}

    for key, value in map do
        table.insert(array, {
            [useKeyIndex] = key :: K | V,
            [useValueIndex] = value,
        })
    end

    return array
end





return entries :: EntriesFn__DARKLUA_TYPE_m
end function __DARKLUA_BUNDLE_MODULES.W():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.W if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.W=v end return v.c end end do local function __modImpl()
local function invert<K, V>(map: { [K]: V }): { [V]: K }
    if next(map) == nil then
        return map :: any
    end

    local result = {}
    for key, value in map do
        result[value] = key
    end
    return result
end

return invert
end function __DARKLUA_BUNDLE_MODULES.X():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.X if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.X=v end return v.c end end do local function __modImpl()
local function isEmpty(value: { [any]: any }): boolean
    return next(value) == nil
end

return isEmpty
end function __DARKLUA_BUNDLE_MODULES.Y():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Y if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Y=v end return v.c end end do local function __modImpl()
local function keys<K, V>(map: { [K]: V }): { K }
    local result = {}
    for key in map do
        table.insert(result, key)
    end
    return result
end

return keys
end function __DARKLUA_BUNDLE_MODULES.Z():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Z if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Z=v end return v.c end end do local function __modImpl()
local function mapEntries<K, V, K2, V2>(map: { [K]: V }, mapFn: (key: K, value: V) -> (K2?, V2?)): { [K2]: V2 }
    local result = {}

    for key, value in map do
        local newKey, newValue = mapFn(key, value)
        if newKey ~= nil and newValue ~= nil then
            result[newKey] = newValue
        end
    end

    return result
end

return mapEntries
end function __DARKLUA_BUNDLE_MODULES._():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache._ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache._=v end return v.c end end do local function __modImpl()
local None = table.freeze(setmetatable({}, {
    __index = function()
        error('attempt to index on None symbol')
    end,
    __tostring = function()
        return '<None>'
    end,
}))

return None
end function __DARKLUA_BUNDLE_MODULES.aa():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aa if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aa=v end return v.c end end do local function __modImpl()
local None = __DARKLUA_BUNDLE_MODULES.aa()

local function mapValues<K, V, W>(map: { [K]: V }, mapFn: (value: V, key: K) -> W?): { [K]: W }
    local result = {}

    for key, value in map do
        local newValue = mapFn(value, key)
        if newValue ~= nil and newValue ~= (None :: any) then
            result[key] = newValue
        end
    end

    return result
end

return mapValues
end function __DARKLUA_BUNDLE_MODULES.ab():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ab if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ab=v end return v.c end end do local function __modImpl()
local None = __DARKLUA_BUNDLE_MODULES.aa()

local function merge<T, U...>(...: U...): any
    local first = nil
    local firstIndex = nil
    local length = select('#', ...)

    for i = 1, length do
        local mergeMap = select(i, ...)

        if mergeMap ~= nil then
            firstIndex = i
            first = mergeMap
            break
        end
    end

    if first == nil then
        error('attempt to merge only nil values')
    end

    if firstIndex == length then
        return first
    end

    local result = nil

    for i = firstIndex + 1, length do
        local mergeMap = select(i, ...)

        if mergeMap ~= nil then
            if result == nil then
                result = table.clone(first)
                setmetatable(result, nil)
            end

            local metatable = getmetatable(mergeMap)

            if metatable ~= nil and type(metatable.__call) == 'function' then
                for key, value in pairs(mergeMap) do
                    if value == None then
                        result[key] = nil
                    else
                        result[key] = value
                    end
                end
            else
                for key, value in mergeMap do
                    if value == None then
                        result[key] = nil
                    else
                        result[key] = value
                    end
                end
            end
        end
    end

    return result or first
end








return (merge :: any) :: merge1__DARKLUA_TYPE_n & merge2__DARKLUA_TYPE_o & merge3__DARKLUA_TYPE_p & merge4__DARKLUA_TYPE_q & merge5__DARKLUA_TYPE_r & mergeAll__DARKLUA_TYPE_s
end function __DARKLUA_BUNDLE_MODULES.ac():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ac if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ac=v end return v.c end end do local function __modImpl()
local isEmpty = __DARKLUA_BUNDLE_MODULES.Y()

local function remove<K, V>(map: { [K]: V }, ...: K?)
    local removeLength = select('#', ...)

    if removeLength == 0 or isEmpty(map) then
        return map
    else
        local result = nil

        for i = 1, removeLength do
            local key: K = select(i, ...)

            if key ~= nil and map[key] ~= nil then
                result = result or table.clone(map)
                result[key] = nil
            end
        end

        return result or map
    end
end

return remove
end function __DARKLUA_BUNDLE_MODULES.ad():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ad if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ad=v end return v.c end end do local function __modImpl()
local function values<K, V>(map: { [K]: V }): { V }
    local result = {}
    for _, value in map do
        table.insert(result, value)
    end
    return result
end

return values
end function __DARKLUA_BUNDLE_MODULES.ae():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ae if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ae=v end return v.c end end do local function __modImpl()
local type = __DARKLUA_BUNDLE_MODULES.a()



local function fromArray<T>(array: { T }): Set__DARKLUA_TYPE_t<T>
    local set: Set__DARKLUA_TYPE_t<T> = {}
    for _, element in array do
        set[element] = true
    end
    return set
end

return fromArray
end function __DARKLUA_BUNDLE_MODULES.af():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.af if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.af=v end return v.c end end do local function __modImpl()
local WEAK_KEYS_METATABLE = { __mode = 'k' }

local function WeakMap<K, V>(default: { [K]: V }?): { [K]: V }
    local value = default or {}
    return setmetatable(value :: any, WEAK_KEYS_METATABLE) :: any
end

return WeakMap
end function __DARKLUA_BUNDLE_MODULES.ag():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ag if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ag=v end return v.c end end do local function __modImpl()
local setType = __DARKLUA_BUNDLE_MODULES.a()



local Disk = {
    Array = {
        all = __DARKLUA_BUNDLE_MODULES.b(),
        alternate = __DARKLUA_BUNDLE_MODULES.d(),
        any = __DARKLUA_BUNDLE_MODULES.e(),
        average = __DARKLUA_BUNDLE_MODULES.f(),
        averageBy = __DARKLUA_BUNDLE_MODULES.g(),
        concat = __DARKLUA_BUNDLE_MODULES.h(),
        contains = __DARKLUA_BUNDLE_MODULES.i(),
        copy = __DARKLUA_BUNDLE_MODULES.j(),
        deduplicate = __DARKLUA_BUNDLE_MODULES.k(),
        deduplicateByKey = __DARKLUA_BUNDLE_MODULES.l(),
        filter = __DARKLUA_BUNDLE_MODULES.m(),
        find = __DARKLUA_BUNDLE_MODULES.n(),
        findIndex = __DARKLUA_BUNDLE_MODULES.o(),
        findIndexByValue = __DARKLUA_BUNDLE_MODULES.p(),
        findMap = __DARKLUA_BUNDLE_MODULES.q(),
        flatMap = __DARKLUA_BUNDLE_MODULES.s(),
        flatten = __DARKLUA_BUNDLE_MODULES.t(),
        fromFn = __DARKLUA_BUNDLE_MODULES.u(),
        fromTryFn = __DARKLUA_BUNDLE_MODULES.v(),
        isArray = __DARKLUA_BUNDLE_MODULES.r()
,
        isEmpty = __DARKLUA_BUNDLE_MODULES.w(),
        map = __DARKLUA_BUNDLE_MODULES.x(),
        maximum = __DARKLUA_BUNDLE_MODULES.y(),
        maximumBy = __DARKLUA_BUNDLE_MODULES.z(),
        minimum = __DARKLUA_BUNDLE_MODULES.A(),
        minimumBy = __DARKLUA_BUNDLE_MODULES.B(),
        partition = __DARKLUA_BUNDLE_MODULES.C(),
        pop = __DARKLUA_BUNDLE_MODULES.D(),
        popFirst = __DARKLUA_BUNDLE_MODULES.E(),
        product = __DARKLUA_BUNDLE_MODULES.F(),
        productBy = __DARKLUA_BUNDLE_MODULES.G(),
        push = __DARKLUA_BUNDLE_MODULES.H(),
        range = __DARKLUA_BUNDLE_MODULES.I(),
        reduce = __DARKLUA_BUNDLE_MODULES.c()
,
        removeIndexes = __DARKLUA_BUNDLE_MODULES.L(),
        removeSortedIndexes = __DARKLUA_BUNDLE_MODULES.J()
,
        removeValues = __DARKLUA_BUNDLE_MODULES.M(),
        reverse = __DARKLUA_BUNDLE_MODULES.N(),
        reversed = __DARKLUA_BUNDLE_MODULES.N(),
        sort = __DARKLUA_BUNDLE_MODULES.K()
,
        sortByKey = __DARKLUA_BUNDLE_MODULES.O(),
        stepBy = __DARKLUA_BUNDLE_MODULES.P(),
        sum = __DARKLUA_BUNDLE_MODULES.Q(),
        sumBy = __DARKLUA_BUNDLE_MODULES.R(),
        takeWhile = __DARKLUA_BUNDLE_MODULES.S(),
        zip = __DARKLUA_BUNDLE_MODULES.T(),
    },
    Map = {
        copy = __DARKLUA_BUNDLE_MODULES.U(),
        count = __DARKLUA_BUNDLE_MODULES.V(),
        entries = __DARKLUA_BUNDLE_MODULES.W(),
        invert = __DARKLUA_BUNDLE_MODULES.X(),
        isEmpty = __DARKLUA_BUNDLE_MODULES.Y(),
        keys = __DARKLUA_BUNDLE_MODULES.Z(),
        mapEntries = __DARKLUA_BUNDLE_MODULES._(),
        mapValues = __DARKLUA_BUNDLE_MODULES.ab(),
        merge = __DARKLUA_BUNDLE_MODULES.ac(),
        remove = __DARKLUA_BUNDLE_MODULES.ad(),
        values = __DARKLUA_BUNDLE_MODULES.ae(),
    },
    Set = {
        fromArray = __DARKLUA_BUNDLE_MODULES.af(),
    },
    None = __DARKLUA_BUNDLE_MODULES.aa()
,
    WeakMap = __DARKLUA_BUNDLE_MODULES.ag(),
}

return Disk
end function __DARKLUA_BUNDLE_MODULES.ah():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ah if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ah=v end return v.c end end do local function __modImpl()local module = __DARKLUA_BUNDLE_MODULES.ah()
return module end function __DARKLUA_BUNDLE_MODULES.ai():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ai if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ai=v end return v.c end end do local function __modImpl()
























local Prefix: PrefixStatic__DARKLUA_TYPE_y = {} :: any
local PrefixMetatable = {
    __index = Prefix,
    __eq = function(self: Prefix__DARKLUA_TYPE_x, other: Prefix__DARKLUA_TYPE_x): boolean
        return self:equal(other)
    end,
}

local function new(self: PrefixEnum__DARKLUA_TYPE_w)
    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix.Verbatim(value: string): Prefix__DARKLUA_TYPE_x
    return new({ type = 'Verbatim', value = value })
end

function Prefix.VerbatimUNC(hostName: string, shareName: string): Prefix__DARKLUA_TYPE_x
    return new({ type = 'VerbatimUNC', hostName = hostName, shareName = shareName })
end

function Prefix.VerbatimDisk(value: string): Prefix__DARKLUA_TYPE_x
    return new({ type = 'VerbatimDisk', value = value })
end

function Prefix.DeviceNS(value: string): Prefix__DARKLUA_TYPE_x
    return new({ type = 'DeviceNS', value = value })
end

function Prefix.UNC(hostName: string, shareName: string): Prefix__DARKLUA_TYPE_x
    return new({ type = 'UNC', hostName = hostName, shareName = shareName })
end

function Prefix.Disk(value: string): Prefix__DARKLUA_TYPE_x
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

function Prefix:clone(): Prefix__DARKLUA_TYPE_x
    local self = table.clone(self)

    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix:equal(other: Prefix__DARKLUA_TYPE_x): boolean
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
end function __DARKLUA_BUNDLE_MODULES.aj():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aj if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aj=v end return v.c end end do local function __modImpl()

















local PrefixParserSlice: PrefixParserSliceStatic__DARKLUA_TYPE_C = {} :: any
local PrefixParserSliceMetatable = {
    __index = PrefixParserSlice,
}

function PrefixParserSlice.new(path: string, prefix: string): PrefixParserSlice__DARKLUA_TYPE_z
    local self: Private__DARKLUA_TYPE_A = {
        _path = path,
        _prefix = prefix,
        _index = 1,
    }

    return setmetatable(self, PrefixParserSliceMetatable) :: any
end

function PrefixParserSlice:stripPrefix(prefix: string): PrefixParserSlice__DARKLUA_TYPE_z?
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_B = self :: any

    local prefixLength = #prefix
    if string.sub(self._prefix, self._index, self._index + prefixLength - 1) == prefix then
        local self: Private__DARKLUA_TYPE_A = {
            _path = self._path,
            _prefix = self._prefix,
            _index = self._index + prefixLength,
        }

        return setmetatable(self, PrefixParserSliceMetatable) :: any
    end
    return nil
end

function PrefixParserSlice:prefixBytes(): string
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_B = self :: any

    return string.sub(self._path, 1, self._index)
end

function PrefixParserSlice:finish(): string
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_B = self :: any

    return string.sub(self._path, self._index)
end

return PrefixParserSlice
end function __DARKLUA_BUNDLE_MODULES.ak():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ak if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ak=v end return v.c end end do local function __modImpl()
local PrefixParserSlice = __DARKLUA_BUNDLE_MODULES.ak()



















local PrefixParser: PrefixParserStatic__DARKLUA_TYPE_H = {} :: any
local PrefixParserMetatable = {
    __index = PrefixParser,
}

function PrefixParser.new(path: string, length: number): PrefixParser__DARKLUA_TYPE_E
    local self: Private__DARKLUA_TYPE_F = {
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

function PrefixParser:asSlice(): PrefixParserSlice__DARKLUA_TYPE_D
    local self: PrivatePrefixParser__DARKLUA_TYPE_G = self :: any

    return PrefixParserSlice.new(self._path, string.sub(self._prefix, 1, math.min(#self._path, 8)))
end

return PrefixParser
end function __DARKLUA_BUNDLE_MODULES.al():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.al if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.al=v end return v.c end end do local function __modImpl()-- https://github.com/rust-lang/rust/blob/master/library/std/src/sys/path/windows.rs


local Prefix = __DARKLUA_BUNDLE_MODULES.aj()
local PrefixParser = __DARKLUA_BUNDLE_MODULES.al()




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

local function parsePrefix(path: string): Prefix__DARKLUA_TYPE_I?
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
end function __DARKLUA_BUNDLE_MODULES.am():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.am if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.am=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.aj()
local parsePrefixWindows = __DARKLUA_BUNDLE_MODULES.am()



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

local function parsePrefixUnix(_path: string): Prefix__DARKLUA_TYPE_K?
    return nil
end

local parsePrefix: (path: string) -> Prefix__DARKLUA_TYPE_K? = if IS_WINDOWS
    then parsePrefixWindows
    else parsePrefixUnix

return {
    MAIN_SEPARATOR_STR = MAIN_SEPARATOR_STR,
    isSepByte = isSepByte,
    isVerbatimSep = isVerbatimSep,
    parsePrefix = parsePrefix,
}
end function __DARKLUA_BUNDLE_MODULES.an():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.an if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.an=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.aj()
local sysPath = __DARKLUA_BUNDLE_MODULES.an()

local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR
































local Component: ComponentStatic__DARKLUA_TYPE_R = {} :: any
local ComponentMetatable = {
    __index = Component,
    __tostring = function(self)
        return self:toString()
    end,
    __eq = function(self: Prefix__DARKLUA_TYPE_L, other: Prefix__DARKLUA_TYPE_L): boolean
        return self:equal(other)
    end,
}

function Component.normal(value: string): Component__DARKLUA_TYPE_Q
    local self: ComponentEnum__DARKLUA_TYPE_O = { type = 'normal', value = value }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.rootDir(): Component__DARKLUA_TYPE_Q
    local self: ComponentEnum__DARKLUA_TYPE_O = { type = 'rootDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.curDir(): Component__DARKLUA_TYPE_Q
    local self: ComponentEnum__DARKLUA_TYPE_O = { type = 'curDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.parentDir(): Component__DARKLUA_TYPE_Q
    local self: ComponentEnum__DARKLUA_TYPE_O = { type = 'parentDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.prefix(raw: string, prefix: Prefix__DARKLUA_TYPE_L): Component__DARKLUA_TYPE_Q
    local self: PrefixComponent__DARKLUA_TYPE_M = { type = 'prefix', raw = raw, parsed = prefix }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component:toString(): string
    local componentType = self.type
    return if componentType == 'normal'
        then (self :: NormalComponent__DARKLUA_TYPE_N & ComponentCommon__DARKLUA_TYPE_P).value
        elseif componentType == 'curDir' then '.'
        elseif componentType == 'parentDir' then '..'
        elseif componentType == 'rootDir' then MAIN_SEPARATOR_STR
        else (self :: PrefixComponent__DARKLUA_TYPE_M & ComponentCommon__DARKLUA_TYPE_P).raw
end

function Component:equal(other: Component__DARKLUA_TYPE_Q): boolean
    local selfType = self.type

    if selfType ~= other.type then
        return false
    end

    if selfType == 'normal' then
        return (self :: NormalComponent__DARKLUA_TYPE_N & ComponentCommon__DARKLUA_TYPE_P).value
            == (other :: NormalComponent__DARKLUA_TYPE_N & ComponentCommon__DARKLUA_TYPE_P).value
    elseif selfType == 'prefix' then
        return (self :: PrefixComponent__DARKLUA_TYPE_M & ComponentCommon__DARKLUA_TYPE_P).parsed:equal(
            (other :: PrefixComponent__DARKLUA_TYPE_M & ComponentCommon__DARKLUA_TYPE_P).parsed
        )
    end

    return true
end

return Component
end function __DARKLUA_BUNDLE_MODULES.ao():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ao if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ao=v end return v.c end end do local function __modImpl()
local Disk = __DARKLUA_BUNDLE_MODULES.ai()

local Array = Disk.Array



































local Rev: RevStatic__DARKLUA_TYPE_W = {} :: any
local RevMetatable = {
    __index = Rev,
    __iter = function<T>(self: PrivateRev__DARKLUA_TYPE_V<T>)
        local items = self:collect()
        return next, items
    end,
}

function Rev.new<T>(iter: DoubleEndedIterator__DARKLUA_TYPE_T<T>): Rev__DARKLUA_TYPE_S<T>
    local self: Private__DARKLUA_TYPE_U<T> = {
        _iter = iter,
    }

    return setmetatable(self, RevMetatable) :: any
end

function Rev:next<T>(): T?
    local self: PrivateRev__DARKLUA_TYPE_V<T> = self :: any

    return self._iter:nextBack()
end

function Rev:collect<T>(): { T }
    local self: PrivateRev__DARKLUA_TYPE_V<T> = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Rev:nextBack<T>(): T?
    local self: PrivateRev__DARKLUA_TYPE_V<T> = self :: any

    return self._iter:next()
end

function Rev:clone<T>(): Rev__DARKLUA_TYPE_S<T>
    local self: PrivateRev__DARKLUA_TYPE_V<T> = self :: any

    return Rev.new(self._iter:clone())
end

return Rev
end function __DARKLUA_BUNDLE_MODULES.ap():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ap if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ap=v end return v.c end end do local function __modImpl()
local Disk = __DARKLUA_BUNDLE_MODULES.ai()

local Component = __DARKLUA_BUNDLE_MODULES.ao()
local Prefix = __DARKLUA_BUNDLE_MODULES.aj()
local Rev = __DARKLUA_BUNDLE_MODULES.ap()
local sysPath = __DARKLUA_BUNDLE_MODULES.an()

local isSepByte = sysPath.isSepByte
local isVerbatimSep = sysPath.isVerbatimSep





local Array = Disk.Array










































local function getStateValue(state: State__DARKLUA_TYPE_2)
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






















local Components: ComponentsStatic__DARKLUA_TYPE_5 = {} :: any
local ComponentsMetatable = {
    __index = Components,
    __iter = function(self: PrivateComponents__DARKLUA_TYPE_4)
        local items = self:collect()
        return next, items
    end,
}

function Components.new(path: string, prefix: Prefix__DARKLUA_TYPE_Y?, hasPhysicalRoot: boolean): Components__DARKLUA_TYPE_0
    local self: Private__DARKLUA_TYPE_3 = {
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
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local prefix = self.prefix
    return if prefix then prefix:len() else 0
end

function Components:prefixVerbatim(): boolean
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local prefix = self.prefix
    return if prefix then prefix:isVerbatim() else false
end

-- how much of the prefix is left from the point of view of iteration?
function Components:prefixRemaining(): number
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local front = self._front
    return if front == 'Prefix' then self:prefixLen() else 0
end

-- Given the iteration so far, how much of the pre-State::Body path is left?
function Components:lenBeforeBody(): number
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local front: State__DARKLUA_TYPE_2 = self._front
    local isBeforeStartDir = getStateValue(front) <= getStateValue('StartDir')
    local root = if isBeforeStartDir and self._hasPhysicalRoot then 1 else 0
    local curDir = if isBeforeStartDir and self:includeCurDir() then 1 else 0

    return self:prefixRemaining() + root + curDir
end

-- is the iteration complete?
function Components:finished(): boolean
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local front: State__DARKLUA_TYPE_2 = self._front
    local back: State__DARKLUA_TYPE_2 = self._back
    return front == 'Done' or back == 'Done' or getStateValue(front) > getStateValue(back)
end

function Components:isSepByte(b: char__DARKLUA_TYPE__): boolean
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    return if self:prefixVerbatim() then isVerbatimSep(b) else isSepByte(b)
end

function Components:asPathString(): string
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local comps: PrivateComponents__DARKLUA_TYPE_4 = self:clone() :: any
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
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
function Components:parseSingleComponent(comp: string): Component__DARKLUA_TYPE_X?
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
function Components:parseNextComponent(): (number, Component__DARKLUA_TYPE_X?)
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
function Components:parseNextComponentBack(): (number, Component__DARKLUA_TYPE_X?)
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    while #self._path > self:lenBeforeBody() do
        local size, comp = self:parseNextComponentBack()
        if comp ~= nil then
            return
        else
            self._path = string.sub(self._path, 1, #self._path - size)
        end
    end
end

function Components:next(): Component__DARKLUA_TYPE_X?
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    while not self:finished() do
        local front: State__DARKLUA_TYPE_2 = self._front

        if front == 'Prefix' then
            self._front = 'StartDir'
            local prefixLen = self:prefixLen()
            if prefixLen > 0 then
                local raw = string.sub(self._path, 1, prefixLen)
                self._path = string.sub(self._path, prefixLen + 1)

                return Component.prefix(raw, self.prefix :: Prefix__DARKLUA_TYPE_Y)
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

function Components:collect(): { Component__DARKLUA_TYPE_X }
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Components:rev(): Rev__DARKLUA_TYPE_Z<Component__DARKLUA_TYPE_X>
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    return Rev.new(self:clone())
end

function Components:nextBack(): Component__DARKLUA_TYPE_X?
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    while not self:finished() do
        local back: State__DARKLUA_TYPE_2 = self._back

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
                return Component.prefix(self._path, self.prefix :: Prefix__DARKLUA_TYPE_Y)
            end
        else
            error('unreachable')
        end
    end

    return nil
end

function Components:clone(): Components__DARKLUA_TYPE_0
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any

    local newSelf: PrivateComponents__DARKLUA_TYPE_4 = table.clone(self) :: any

    if newSelf.prefix then
        newSelf.prefix = newSelf.prefix:clone()
    end

    return setmetatable(newSelf, ComponentsMetatable) :: any
end

function Components:equal(other: Components__DARKLUA_TYPE_0): boolean
    local self: PrivateComponents__DARKLUA_TYPE_4 = self :: any
    local other: PrivateComponents__DARKLUA_TYPE_4 = other :: any

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
end function __DARKLUA_BUNDLE_MODULES.aq():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aq if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aq=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.ao()






local function iterAfter<T>(
    iter: T & ComponentIterator__DARKLUA_TYPE_7 & Clone__DARKLUA_TYPE_8<ComponentIterator__DARKLUA_TYPE_7>,
    prefix: T & ComponentIterator__DARKLUA_TYPE_7
): (T & ComponentIterator__DARKLUA_TYPE_7)?
    while true do
        local iterNext = iter:clone()
        local x = iterNext:next()
        local y = prefix:next()

        if x ~= nil and y ~= nil then
            if not x:equal(y) then
                return nil
            end
        elseif y == nil then
            return iter
        else
            return nil
        end
        iter = iterNext :: any
    end
end

return iterAfter
end function __DARKLUA_BUNDLE_MODULES.ar():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ar if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ar=v end return v.c end end do local function __modImpl()-- implementation based on Rust path library
-- https://github.com/rust-lang/rust/blob/bd7d328807a8bb15732ebb764e1ea3df4fbe3fd1/library/std/src/path.rs

local Disk = __DARKLUA_BUNDLE_MODULES.ai()

local Component = __DARKLUA_BUNDLE_MODULES.ao()
local Components = __DARKLUA_BUNDLE_MODULES.aq()
local Prefix = __DARKLUA_BUNDLE_MODULES.aj()
local iterAfter = __DARKLUA_BUNDLE_MODULES.ar()
local sysPath = __DARKLUA_BUNDLE_MODULES.an()

local Array = Disk.Array

local isSepByte = sysPath.isSepByte
local parsePrefix = sysPath.parsePrefix
local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR

local IS_WINDOWS = MAIN_SEPARATOR_STR == '\\'





local function hasRedoxScheme(_s: string): boolean
    return false
end
















local Ancestors: AncestorsStatic__DARKLUA_TYPE_af = {} :: any
local AncestorsMetatable = {
    __index = Ancestors,
}

local function newAncestors(path: Path__DARKLUA_TYPE_ah?): Ancestors__DARKLUA_TYPE_ac
    local self: AncestorsPrivate__DARKLUA_TYPE_ad = {
        _next = path,
    }

    return setmetatable(self, AncestorsMetatable) :: any
end

function Ancestors:next(): Path__DARKLUA_TYPE_ah?
    local self: PrivateAncestors__DARKLUA_TYPE_ae = self :: any

    local next = self._next
    self._next = next and next:parent()

    return next
end

function Ancestors:collect(): { Path__DARKLUA_TYPE_ah }
    local self: PrivateAncestors__DARKLUA_TYPE_ae = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

















































local Path: PathStatic__DARKLUA_TYPE_ak = {} :: any
local PathMetatable = {
    __index = Path,
    __tostring = function(self: Path__DARKLUA_TYPE_ah): string
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
local function hasPhysicalRoot(s: string, prefix: Prefix__DARKLUA_TYPE_ab?): boolean
    local path = if prefix ~= nil then string.sub(s, prefix:len() + 1) else s
    return path ~= '' and isSepByte(string.sub(path, 1, 1))
end

function Path.new(path: string): Path__DARKLUA_TYPE_ah
    local self: Private__DARKLUA_TYPE_ai = {
        _inner = path,

        _prefix = nil :: any,
    }

    return setmetatable(self, PathMetatable) :: any
end

function Path.from(path: AsPath__DARKLUA_TYPE_ag): Path__DARKLUA_TYPE_ah
    local pathType = type(path)
    if pathType == 'string' then
        return Path.new(path :: string)
    elseif Path.is(path) then
        return path :: Path__DARKLUA_TYPE_ah
    elseif Components.is(path) then
        return Path.new(path:asPathString())
    end

    error('unable to create path from value')
end

function Path.is(value: unknown): boolean
    return type(value) == 'table' and getmetatable(value :: any) == PathMetatable
end

function Path:toString(): string
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    return self._inner
end

function Path:toPathBuf(): Path__DARKLUA_TYPE_ah
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    return setmetatable(table.clone(self), PathMetatable) :: any
end

function Path:isAbsolute(): boolean
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

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
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    return self:components():hasRoot()
end

function Path:parent(): Path__DARKLUA_TYPE_ah?
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
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

function Path:ancestors(): Ancestors__DARKLUA_TYPE_ac
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    return newAncestors(self)
end

function Path:fileName(): string?
    local components = self:components()
    local p = components:nextBack()

    return if p and p.type == 'normal' then (p :: any).value else nil
end

function Path:stripPrefix(base: AsPath__DARKLUA_TYPE_ag): Path__DARKLUA_TYPE_ah?
    local result: Components__DARKLUA_TYPE_aa? = iterAfter(self:components(), Path.from(base):components())

    return result and Path.from(result:asPathString())
end

function Path:startsWith(base: AsPath__DARKLUA_TYPE_ag): boolean
    return iterAfter(self:components(), Path.from(base):components()) ~= nil
end

function Path:endsWith(child: AsPath__DARKLUA_TYPE_ag): boolean
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

function Path:join(path: AsPath__DARKLUA_TYPE_ag): Path__DARKLUA_TYPE_ah
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    local buf = self:toPathBuf()
    buf:push(path)
    return buf
end

function Path:withFileName(fileName: string): Path__DARKLUA_TYPE_ah
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    local buf = self:toPathBuf()
    buf:setFileName(fileName)
    return buf
end

function Path:withExtension(extension: string): Path__DARKLUA_TYPE_ah
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    local buf = self:toPathBuf()
    buf:setExtension(extension)
    return buf
end

function Path:components(): Components__DARKLUA_TYPE_aa
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    local prefix = parsePrefix(self._inner)
    return Components.new(
        self._inner,
        prefix,
        hasPhysicalRoot(self._inner, prefix) or hasRedoxScheme(self._inner)
    )
end

function Path:equal(other: Path__DARKLUA_TYPE_ah): boolean
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    return self:components():equal(other:components())
end

function Path:push(path: AsPath__DARKLUA_TYPE_ag): ()
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    local path = Path.from(path) :: PrivatePath__DARKLUA_TYPE_aj

    -- in general, a separator is needed if the rightmost byte is not a separator
    local needSep = if self._inner == ''
        then false
        else not isSepByte(string.sub(self._inner, -1, -1))

    -- in the special case of `C:` on Windows, do *not* add a separator
    local comps = self:components()

    if
        comps:prefixLen() > 0
        and comps:prefixLen() == #(comps :: any)._path
        and (comps.prefix :: Prefix__DARKLUA_TYPE_ab):isDrive()
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

        for _, c: Component__DARKLUA_TYPE_9 in buf :: { any } do
            if needSep and c.type ~= 'rootDir' then
                table.insert(res, MAIN_SEPARATOR_STR)
            end
            table.insert(res, c:toString())

            local prefix: Prefix__DARKLUA_TYPE_ab = (c :: any).parsed
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
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    local parent = self:parent() :: PrivatePath__DARKLUA_TYPE_aj?
    if parent ~= nil then
        self._inner = parent._inner
        return true
    else
        return false
    end
end

function Path:setFileName(fileName: string)
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

    if self:fileName() ~= nil then
        self:pop()
    end
    self:push(fileName)
end

function Path:setExtension(extension: string): boolean
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any

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
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    self._inner = ''
end

function Path:_prefix(): Prefix__DARKLUA_TYPE_ab?
    local self: PrivatePath__DARKLUA_TYPE_aj = self :: any
    return self:components().prefix
end

return Path
end function __DARKLUA_BUNDLE_MODULES.as():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.as if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.as=v end return v.c end end do local function __modImpl()



























return nil
end function __DARKLUA_BUNDLE_MODULES.at():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.at if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.at=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.at()
































return nil
end function __DARKLUA_BUNDLE_MODULES.au():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.au if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.au=v end return v.c end end do local function __modImpl()


































return nil
end function __DARKLUA_BUNDLE_MODULES.av():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.av if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.av=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.au()
local Prefix = __DARKLUA_BUNDLE_MODULES.at()
local Rev = __DARKLUA_BUNDLE_MODULES.av()














































return nil
end function __DARKLUA_BUNDLE_MODULES.aw():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aw if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aw=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.au()
local Components = __DARKLUA_BUNDLE_MODULES.aw()
local Prefix = __DARKLUA_BUNDLE_MODULES.at()














































return nil
end function __DARKLUA_BUNDLE_MODULES.ax():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ax if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ax=v end return v.c end end do local function __modImpl()
local Path = __DARKLUA_BUNDLE_MODULES.ax()
local Component = __DARKLUA_BUNDLE_MODULES.au()





return nil
end function __DARKLUA_BUNDLE_MODULES.ay():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ay if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ay=v end return v.c end end do local function __modImpl()
local Path = __DARKLUA_BUNDLE_MODULES.as()
local types = __DARKLUA_BUNDLE_MODULES.ay()




return {
    Path = (Path :: any) :: {
		new: (path: string) -> Path__DARKLUA_TYPE_aN,
		from: (path: AsPath__DARKLUA_TYPE_aO) -> Path__DARKLUA_TYPE_aN,
		is: (value: unknown) -> boolean,
	},
}
end function __DARKLUA_BUNDLE_MODULES.az():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.az if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.az=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.az()


return module end function __DARKLUA_BUNDLE_MODULES.aA():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aA if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aA=v end return v.c end end do local function __modImpl()
local SOFT_MAX_LINE_LENGTH = 80

local greenteaConstructorsSet = {}

local function highlightWrap(str: string, highlight: string?)
	if highlight then
		return `$${highlight}$:{str}:${highlight}$$`
	else
		return str
	end
end

-- Returns the maximum number of characters in any line
local function lineLengthOf(str: string)
	local maxLength = 0
	local lastIndex = 1
	while true do
		local start, finish = string.find(str, "[^\n]+", lastIndex)
		if not (start and finish) then
			break
		end

		local length = finish - start + 1
		if length > maxLength then
			maxLength = length
		end

		lastIndex = finish + 1
	end
	return maxLength
end

-- Returns the minimum number of spaces prefixing every line
local function spaceLengthOf(str: string)
	local minSpaces
	for _, line in string.split(str, "\n") do
		local start, finish = string.find(line, "^ *")
		if start and finish then
			local length = finish - start + 1
			if not minSpaces or length < minSpaces then
				minSpaces = length
			end
		end
	end
	return minSpaces or 0
end

local function tabFirst(str: string)
	return "    " .. string.gsub(str, "\n", "\n    ")
end

local function tabSecond(str: string)
	return string.gsub(str, "\n", "\n    ")
end






local function parseRange(rangeIn: RangeInput__DARKLUA_TYPE_aW): Range__DARKLUA_TYPE_aU
	if typeof(rangeIn) == "table" then
		if
			typeof(rangeIn.min) == "number"
			and typeof(rangeIn.max) == "number"
			and (rangeIn.minExclusive == nil or typeof(rangeIn.minExclusive) == "boolean")
			and (rangeIn.maxExclusive == nil or typeof(rangeIn.maxExclusive) == "boolean")
		then
			return {
				min = rangeIn.min,
				minExclusive = rangeIn.min and rangeIn.minExclusive or false,
				max = rangeIn.max,
				maxExclusive = rangeIn.max and rangeIn.maxExclusive or false,
			}
		else
			error("invalid range table")
		end
	end

	local rangeNum = tonumber(rangeIn)
	if rangeNum then
		return { min = nil, minExclusive = false, max = rangeNum, maxExclusive = false }
	end
	assert(type(rangeIn) == "string", "analysis hint")

	local leftBracket = "[%[%(]"
	local rightBracket = "[%]%)]"
	local numbers = ".-"

	local prefix, minStr, maxStr, suffix =
		string.match(rangeIn, `^%s*({leftBracket})%s*({numbers}),%s*({numbers})%s*({rightBracket})%s*$`)

	if not prefix then
		error(
			'invalid range string, expected format: one of "[min, max]", "(min, max)", "[min, max)", "(min, max]", or "max" (leave min/max empty for no limit)'
		)
	end

	local minExclusive = prefix == "("
	local maxExclusive = suffix == ")"

	local min: number?
	if minStr == "" then
		min = nil
		minExclusive = false
	else
		min = tonumber(minStr)
		if not min then
			error(`invalid number for min in range string: {minStr}`)
		end
	end
	local max: number?
	if maxStr == "" then
		max = nil
		maxExclusive = false
	else
		max = tonumber(maxStr)
		if not max then
			error(`invalid number for max in range string: {maxStr}`)
		end
	end

	return {
		min = min,
		minExclusive = minExclusive,
		max = max,
		maxExclusive = maxExclusive,
	}
end

local function displayRange(range: Range__DARKLUA_TYPE_aU): string
	if not range.min and not range.max then
		return "[-inf, inf]"
	end

	local leftBracket = range.minExclusive and "(" or "["
	local rightBracket = range.maxExclusive and ")" or "]"
	return leftBracket .. (range.min or "") .. ", " .. (range.max or "") .. rightBracket
end

local function checkRange(value: number, range: Range__DARKLUA_TYPE_aU): boolean
	if range.min then
		if range.minExclusive then
			if value <= range.min then
				return false
			end
		else
			if value < range.min then
				return false
			end
		end
	end

	if range.max then
		if range.maxExclusive then
			if value >= range.max then
				return false
			end
		else
			if value > range.max then
				return false
			end
		end
	end

	return true
end

--- @class GreenTea
local GreenTea = {}

GreenTea.__greenteaConstructorsSet = greenteaConstructorsSet





















local CauseMt = {
	__tostring = function(self: Cause__DARKLUA_TYPE_aX)
		if self.ok then
			return "ok"
		else
			return self:formatErr()
		end
	end,
}

local function newCauseTuple(...: any): { __tuple: { [number]: any, n: number } }
	return { __tuple = table.pack(...) }
end

local function expandCauseTuple(input: any?): ...any
	if type(input) == "table" and input.__tuple then
		return unpack(input.__tuple, 1, input.__tuple.n)
	else
		return input
	end
end

local Cause = {}

local function causeFormatErr(self: Cause__DARKLUA_TYPE_aX)
	if self.ok then
		return "ok"
	else
		local type = self.encompassingType or self.errs[#self.errs].type

		return type:formatErr(self)
	end
end

function Cause.new(ok: boolean, errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_aX
	return setmetatable({ ok = ok, errs = errs, formatErr = causeFormatErr } :: Cause__DARKLUA_TYPE_aX, CauseMt) :: any
end

function Cause.ok(): Cause__DARKLUA_TYPE_aX
	return Cause.new(true, {})
end

function Cause.extendOk(cause: Cause__DARKLUA_TYPE_aX?): Cause__DARKLUA_TYPE_aX
	if not cause then
		return Cause.new(true, {})
	else
		return cause
	end
end

function Cause.err(type: any, input: any?, message: string?): Cause__DARKLUA_TYPE_aX
	return Cause.new(false, { { type = type, input = input, message = message } })
end

function Cause.extendErr(cause: Cause__DARKLUA_TYPE_aX?, type: any, input: any?, message: string?): Cause__DARKLUA_TYPE_aX
	if not cause then
		return Cause.new(false, { { type = type, input = input, message = message } })
	else
		table.insert(cause.errs, { type = type, input = input, message = message })
		return cause
	end
end

function Cause.errs(errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_aX
	return Cause.new(false, errs)
end

function Cause.extendErrs(cause: Cause__DARKLUA_TYPE_aX?, errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_aX
	if not cause then
		return Cause.new(false, errs)
	else
		table.move(errs, 1, #errs, #cause.errs + 1, cause.errs)
		return cause
	end
end











































































































local Type = {}
Type.__index = Type

--- @class Type
--- Represents a type we can check against or inspect.\
--- Use the methods to check against the type.\
--- Use the properties to inspect the type.

--- @type Range { min: number?, minExclusive: boolean, max: number?, maxExclusive: boolean }
--- @within Type

--- @type RangeInput string | number | { min: number?, minExclusive: boolean?, max: number?, maxExclusive: boolean? }
--- @within GreenTea
--- A value that can be parsed as a range.\
--- As a string, can be "[min, max]", "(min, max)", "(min, max]", "(, max]" etc. or a number max inclusive.
--- As a number, it's interpreted as a number max inclusive.

--- @type Cause { ok: boolean, encompassingType: Type?, errs: { { type: any, input: any?, message: string? } }, formatErr: (self: Cause) -> string }
--- @within Type
--- Represents the result of a :matches() call.\
--- Includes a `__tostring` metamethod, which formats to a readable error.

--- @within Type
--- @prop kind string

--- @within Type
--- @prop meta { [string]: any }?
--- Contains user-specified metadata about the type.

--- @within Type
--- @prop basic { typeof: string?, type: string? }?

--- @within Type
--- @prop any { allowNil: boolean? }?

--- @within Type
--- @prop unknown { allowNil: boolean? }?

--- @within Type
--- @prop custom { type: Type?, name: string, typechecker: (any) -> (boolean, any?) }?

--- @within Type
--- @prop number { range: Range?, integer: boolean? }?

--- @within Type
--- @prop string { pattern: string?, bytes: Range?, graphemes: Range?, unicode: boolean? }?

--- @within Type
--- @prop thread { status: { [CoroutineStatus]: boolean }? }?

--- @within Type
--- @prop instanceIsA { class: string }?

--- @within Type
--- @prop literal { value: any }?

--- @within Type
--- @prop tuple { contents: { Type }, vararg: Type? }?

--- @within Type
--- @prop vararg { type: Type, length: Range? }?

--- @within Type
--- @prop fn { args: Type, returns: Type }?

--- @within Type
--- @prop table { contents: { [string]: Type }, indexer: { key: Type, value: Type }, array: boolean?, count: Range?, raw: boolean? }?

--- @within Type
--- @prop intersection { contents: { Type } }?

--- @within Type
--- @prop union { contents: { Type }, optional: boolean? }?

--- Returns a value with information about whether or not the input matches the type.
function Type.matches(self: Type__DARKLUA_TYPE_a1, ...: any): (boolean, Cause__DARKLUA_TYPE_aX)
	local cause = self._matches(...)
	cause.encompassingType = self
	return cause.ok, cause
end

--- Errors if the input does not match the type, otherwise returns the input.
function Type.assert<T...>(self: Type__DARKLUA_TYPE_a1, ...: T...): T...
local ok, cause = self:matches(...)
	if not ok then
		error(cause:formatErr())
	end
	return ...
end

--- Formats the type for display to the user.
function Type.format(self: Type__DARKLUA_TYPE_a1): string
	return self._format({}, SOFT_MAX_LINE_LENGTH, {})
end

--- Wraps a function with type asserts for its input args and returns.\
--- \
--- This implementation is not ergonomic, and is easily confused with GreenTea.wrapFn.
--- For this reason, Type.wrapFn will be removed in the next breaking release.\
--- @deprecated v0.4.11 -- use `GreenTea.wrapFn` instead
function Type.wrapFn<T>(self: Type__DARKLUA_TYPE_a1, fn: T): T
	assert(typeof(fn) == "function", "fn must be a function")
	assert(self.fn ~= nil, "self must be a GreenTea.fn type")

	return function(...: any)
		self.fn.args:assert(...)

		return self.fn.returns:assert(fn(...))
	end :: any
end

--- In type definitions via `typeof(Type:type())`, returns the Luau type this
--- GreenTea type represents.\
--- At runtime, returns self. This allows you to compose complex GreenTea types
--- by passing GreenTea.type() into a GreenTea constructor. (Only applies when
--- "built" with `GreenTea.build(GreenTea constructors here)`)
function Type.type(self: any): ...any
	return self
end

local isStringUnicode

function isStringUnicode(str: string)
	return utf8.len(str) ~= nil
end

local function truncate(count: number, str: string)
	if not isStringUnicode(str) then
		return "<invalid unicode>"
	end

	if #str < count then
		return str
	end

	local offset = utf8.offset(str, count + 1)
	if not offset then
		return "<invalid unicode>"
	end

	return str:sub(1, offset - 1)
end

function Type.__call(self: Type__DARKLUA_TYPE_a1, ...: any): (boolean, string?)
	local ok, cause = self:matches(...)
	if ok then
		return true
	else
		return false, tostring(cause)
	end
end

function Type.__tostring(self: Type__DARKLUA_TYPE_a1): string
	return `GreenTea.Type({self:format()})`
end

local function tostringLiteral(value: any?)
	if typeof(value) == "string" then
		return string.format("%q", value)
	else
		return tostring(value)
	end
end

local function displayInputType(...: any?)
	local inputStr, typeStr
	if select("#", ...) <= 1 then
		local input = ...
		if input and typeof(input) == "table" and input.__tuple then
			return displayInputType(expandCauseTuple(input))
		end

		if typeof(...) == "string" then
			inputStr = string.format("%q", ...)
		else
			inputStr = tostring(...)
		end

		-- disabled for now, as it can take a long time to build a GreenTea type
		-- for large inputs.

		-- local gtType = GreenTea.typeof(...) :: any
		-- typeStr = gtType:format():gsub("\n%s*", " ")

		typeStr = typeof(...)
	else
		local length = select("#", ...)
		local inputs = table.create(length)
		local inputStrBuilder = table.create(length)
		local typeStrBuilder = table.create(length)
		for i = 1, select("#", ...) do
			local input = select(i, ...)

			table.insert(inputs, GreenTea.typeof(input))

			-- selene: allow(shadowing)
			local inputStr
			if typeof(input) == "string" then
				inputStr = string.format("%q", input)
			else
				inputStr = tostring(input)
			end
			table.insert(inputStrBuilder, inputStr)

			table.insert(typeStrBuilder, typeof(input))
		end

		-- disabled for now, as it can take a long time to build a GreenTea type
		-- for large inputs.

		-- typeStr = GreenTea.tuple(unpack(inputs))

		typeStr = `({table.concat(typeStrBuilder, ", ")})`

		inputStr = `({table.concat(inputStrBuilder, ", ")})`
	end

	inputStr = truncate(20, inputStr)
	typeStr = truncate(20, typeStr)

	return `{typeStr} ({inputStr})`
end

--- Formats the type for display to the user highlighting a specific type.
function Type.formatErr(self: Type__DARKLUA_TYPE_a1, cause: Cause__DARKLUA_TYPE_aX): string
	-- By the way, this is kind of hacky and not really the right way to do
	-- this. Got to replace formatting entirely with something more made for it
	-- someday. But this does the job for now, and its internals aren't exposed,
	-- so we can replace it later!

	local header = "type error"

	local headerErr = cause.errs[1]
	if headerErr.message then
		header = string.gsub(headerErr.message, "$input", displayInputType(headerErr.input))
	else
		header = `expected {headerErr.type:format()}, got {displayInputType(headerErr.input)}`
	end

	local errorsForFormat = {}
	for index, err in cause.errs do
		if not (err.message or index == 1) then
			continue
		end
		errorsForFormat[err.type] = `error{index}`
	end

	local formattedStr = self._format(errorsForFormat, SOFT_MAX_LINE_LENGTH, {})

	formattedStr = `\n{formattedStr}\n`

	local order = {}
	for numStr in string.gmatch(formattedStr, "%$%$error(%d+)%$:") do
		local num = tonumber(numStr) :: number
		table.insert(order, num)
	end

	for orderIndex = #order, 1, -1 do
		local index = order[orderIndex]
		local err = cause.errs[index]
		formattedStr = string.gsub(
			formattedStr,
			`([^\n]*)$$error{index}$:(.*):$error{index}$$([^\n]*)\n(.*)$`,
			function(pre: string, mid: string, post: string, everythingElse: string)
				local errPointer
				if string.find(mid, "\n", 1, true) == nil then
					local preNoAnnotations = string.gsub(string.gsub(pre, "%$%$error%d+%$:", ""), ":%$error%d+%$%$", "")
					errPointer = string.rep(" ", #preNoAnnotations) .. string.rep("^", #mid)
				else
					local realStr = `{pre}{mid}{post}`
					local lineLength = lineLengthOf(realStr)
					local spaceLength = spaceLengthOf(realStr)

					errPointer = string.rep(" ", spaceLength) .. string.rep("^", lineLength - spaceLength)
				end

				if err.message then
					errPointer = `{errPointer} $$error{index}$$`
				end

				local preLines = {}

				while true do
					local nextLine, newEverythingElse = string.match(everythingElse, "^([^\n]*)\n(.*)$")
					if not (nextLine and newEverythingElse) then
						break
					end
					if string.match(nextLine, "^%s*^") then
						table.insert(preLines, nextLine)
						everythingElse = newEverythingElse
					else
						break
					end
				end

				if preLines[1] then
					return `{pre}{mid}{post}\n{table.concat(preLines, "\n")}\n{errPointer}\n{everythingElse}`
				else
					return `{pre}{mid}{post}\n{errPointer}\n{everythingElse}`
				end
			end :: any
		)
	end

	for index, err in cause.errs do
		if err.message then
			local errMessage = string.gsub(err.message, "$input", displayInputType(err.input))
			formattedStr = string.gsub(formattedStr, `%$%$error{index}%$%$`, errMessage)
		end
	end

	formattedStr = string.gsub(
		formattedStr,
		"\n(%s*)(^+) ([^\n]+)",
		function(spaces, carets, errMessage): string?
			if #spaces + #carets + #errMessage + 1 <= SOFT_MAX_LINE_LENGTH then
				return nil
			end

			return `\n{spaces}{carets}\n{string.rep(" ", #spaces)}{errMessage}`
		end :: any
	)

	formattedStr = formattedStr:sub(1, -2) -- remove final newline

	return `{header}{formattedStr}`
end

--- Returns whether or not the input value is a GreenTea.Type object.
function GreenTea.isGreenTeaType(value: any)
	return typeof(value) == "table" and getmetatable(value) == Type
end

GreenTea.isGtType = GreenTea.isGreenTeaType

local function newBasicType(typeName: string, useType: boolean?)
	return function()
		local self
		self = {
			kind = "basic",
			basic = {
				typeof = if useType then nil else typeName,
				type = if useType then typeName else nil,
			},
			_matches = function(input: any)
				local inputType = useType and type(input) or typeof(input)
				if inputType == typeName then
					return Cause.ok()
				else
					return Cause.err(self, input, `expected {typeName}, got $input`)
				end
			end,
			_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
				return highlightWrap(typeName, highlight[self])
			end,
		}
		return setmetatable(self :: any, Type)
	end
end

GreenTea.__newBasicType = newBasicType

--- Creates a new GreenTea Type that matches any value, excluding nil.
function GreenTea.any(options: { allowNil: boolean? }?): any
	local allowNil = options and options.allowNil

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "any",
		any = {
			allowNil = (allowNil or nil) :: boolean?,
		},
		_matches = function(input: any)
			if not allowNil and input == nil then
				return Cause.err(self, input, "expected non-nil, got nil")
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			return highlightWrap("any", highlight[self])
		end,
	}
	return setmetatable(self :: any, Type)
end

--- Creates a new GreenTea Type that matches any value, excluding nil.\
--- This returns the unknown type, which has different behavior from any.\
--- The runtime typechecking behavior is the same as GreenTea.any.
function GreenTea.unknown(options: { allowNil: boolean? }?): unknown
	local allowNil = options and options.allowNil

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "unknown",
		unknown = {
			allowNil = (allowNil or nil) :: boolean?,
		},
		_matches = function(input: any)
			if not allowNil and input == nil then
				return Cause.err(self, input, "expected non-nil, got nil")
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			return highlightWrap("unknown", highlight[self])
		end,
	}
	return setmetatable(self :: any, Type)
end

--- Creates a new GreenTea Type that matches no values.
function GreenTea.never(): never
	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "never",
		_matches = function(input: any)
			return Cause.err(self, input, "expected never, got $input")
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			return highlightWrap("never", highlight[self])
		end,
	}
	return setmetatable(self, Type) :: any
end

local any = nil :: any

--- Creates a new GreenTea Type that matches boolean values.
function GreenTea.boolean(): boolean
	return any
end

GreenTea.boolean = newBasicType("boolean") :: () -> boolean
GreenTea.bool = GreenTea.boolean

--- Creates a new GreenTea Type that matches number values.
function GreenTea.Instance(): Instance
	return any
end

GreenTea.Instance = newBasicType("Instance") :: () -> Instance


local coroutineStatuses = { "dead", "normal", "running", "suspended" }

--- Creates a new GreenTea Type that matches coroutine values.
function GreenTea.coroutine(options: { status: CoroutineStatus__DARKLUA_TYPE_a2 | { CoroutineStatus__DARKLUA_TYPE_a2 } | nil }?): thread
	local expectedStatusSet
	local expectedStatusStr = "any"
	if options and options.status then
		expectedStatusSet = {}
		if type(options.status) == "string" then
			expectedStatusSet[options.status] = true
		elseif type(options.status) == "table" then
			for _, v in options.status do
				expectedStatusSet[v] = true
			end
		end

		local expectedStatusStrBuilder = {}
		for k, _ in expectedStatusSet do
			if not table.find(coroutineStatuses, k) then
				error(`{k} is not a valid coroutine status`)
			end

			table.insert(expectedStatusStrBuilder, k)
		end

		table.sort(expectedStatusStrBuilder)
		expectedStatusStr = table.concat(expectedStatusStrBuilder, " | ")
		if #expectedStatusStrBuilder > 1 then
			expectedStatusStr = `({expectedStatusStr})`
		end
	end

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "thread",
		thread = {
			status = expectedStatusSet,
		},
		_matches = function(input: any)
			if type(input) ~= "thread" then
				return Cause.err(self, input, "expected thread, got $input")
			end

			if expectedStatusSet then
				local coroutineStatus = coroutine.status(input)

				if not expectedStatusSet[coroutineStatus] then
					return Cause.err(
						self,
						input,
						`expected thread with status {expectedStatusStr}, got thread with status {coroutineStatus}`
					)
				end
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			if expectedStatusSet then
				return highlightWrap(`thread<status: {expectedStatusStr}>`, highlight[self])
			else
				return highlightWrap("thread", highlight[self])
			end
		end,
	}
	return setmetatable(self, Type) :: any
end

GreenTea.thread = GreenTea.coroutine

--- Creates a new GreenTea Type that matches buffer values.
function GreenTea.buffer(): buffer
	-- filler function to make Moonwave happy
	return any
end

GreenTea.buffer = newBasicType("buffer") :: () -> buffer

GreenTea.userdata = newBasicType("userdata", true) :: () -> any

--- Creates a new GreenTea Type that matches nil values.
function GreenTea.none(): nil
	return any
end

GreenTea.none = newBasicType("nil") :: () -> nil

--- Creates a new GreenTea Type that matches a value literally.\
--- This is checked with a basic == comparison.
function GreenTea.literal<T>(value: T): T
	local literalStr
	if typeof(value) == "string" then
		literalStr = string.format("%q", value)
	else
		literalStr = tostring(value)
	end

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "literal",
		literal = {
			value = value,
		},
		_matches = function(input: any)
			if input == value then
				return Cause.ok()
			else
				return Cause.err(self, input, `expected literally {literalStr}, got $input`)
			end
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			local valueStr
			if typeof(value) == "string" then
				valueStr = literalStr
			else
				valueStr = `literal<{literalStr}>`
			end
			return highlightWrap(valueStr, highlight[self])
		end,
	}
	return setmetatable(self :: any, Type)
end

local allowedEndings = { "spec", "t", "d", "story", "storybook", "bench" }

--- Creates a new GreenTea Type that matches a custom typechecker
--- with GreenTea type as a base.
function GreenTea.withCustom<T>(type: T, typechecker: (any) -> (boolean, any?), name: string?): T
	if not name then
		local source, line, fnName = debug.info(typechecker, "sln")
		source = source or "unknown"
		line = line or 0
		fnName = fnName or ""

		if fnName ~= "" then
			name = fnName
		else
			local scriptNamePre, scriptNamePost = string.match(source, "([^%.]+)%.(.-)$")
			if not (scriptNamePre and scriptNamePost) then
				name = `{source}:{line}`
			else
				if table.find(allowedEndings, scriptNamePost) then
					name = `{scriptNamePre}.{scriptNamePost}:{line}`
				else
					name = `{scriptNamePost}:{line}`
				end
			end
		end
	end
	assert(name, "analysis hint")

	local innerType: Type__DARKLUA_TYPE_a1? = if type ~= nil then GreenTea.typeof(type :: any) else nil

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "custom",
		custom = {
			typechecker = typechecker,
			name = name,
			type = innerType,
		},
		_matches = function(input: any)
			if innerType then
				local cause = innerType._matches(input)
				if not cause.ok then
					return Cause.extendErr(cause, self, input)
				end
			end

			local ok, message = typechecker(input)
			if not ok then
				return Cause.err(self, input, message)
			else
				return Cause.ok()
			end
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			local customFormat = highlightWrap(`custom<{name}>`, highlight[self])
			if innerType then
				local innerTypeFormat = innerType._format(highlight, maxLineLength - 1, recurse)
				local combined = `{innerTypeFormat} & {customFormat}`
				if #combined > maxLineLength then
					return tabSecond(`{innerTypeFormat} & {customFormat}`)
				else
					return combined
				end
			else
				return customFormat
			end
		end,
	}

	return setmetatable(self :: any, Type)
end

--- Creates a new GreenTea Type that matches a custom typechecker
--- with `any` as the base type.
function GreenTea.custom(typechecker: (any) -> (boolean, any?), name: string?): any
	return GreenTea.withCustom(nil, typechecker, name)
end

GreenTea.__highlightWrap = highlightWrap
GreenTea.__Type = Type
GreenTea.__Cause = Cause

--- @function isA
--- @within GreenTea
--- @param class string
--- @return any
--- Call IsA to get a type that matches instances of that class.

--- @prop isA { [string]: any }
--- @within GreenTea
--- Types for individual instance classes.\
--- Index this to get a type that matches instances of that class.\
--- For dynamic class names, or for classes not yet added here,\
--- call this with GreenTea.IsA("ClassName").

--- Creates a new GreenTea Type that matches number values.\
--- Optionally, you can specify a range and whether the number must be an integer.\
--- Regardless of specified limits, the returned Luau type will be a basic number. Limit checking will only be done at runtime.\
--- NOTE: NaN is rejected by default. NaN tends to propogate and "poison" numeric values,
--- and it's rarely actually desired. If you want to _allow_ NaN, set `nan = true` in the limits table.
function GreenTea.number(limits: {
	range: RangeInput__DARKLUA_TYPE_aW?,
	integer: boolean?,
	nan: boolean?,
}?): number
	local range = limits and limits.range and parseRange(limits.range)

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "number",
		number = {
			range = range,
			integer = limits and limits.integer,
			nan = limits and limits.nan,
		},
		_matches = function(input: any)
			if typeof(input) ~= "number" then
				return Cause.err(self, input, "expected number, got $input")
			end

			if limits then
				if range and not checkRange(input, range) then
					return Cause.err(self, input, `input out of range (input: {input})`)
				end
				if limits.integer and input % 1 ~= 0 then
					return Cause.err(self, input, `input is not an integer (input: {input})`)
				end
			end

			if not (limits and limits.nan) then
				if input ~= input then
					return Cause.err(self, input, `input is NaN`)
				end
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			if not limits then
				return highlightWrap("number", highlight[self])
			end

			local limitsStr = {}
			if limits.integer then
				table.insert(limitsStr, "integer")
			end
			if limits.nan then
				table.insert(limitsStr, "NaN allowed")
			end
			if range then
				table.insert(limitsStr, `range {displayRange(range)}`)
			end

			if #limitsStr == 0 then
				return highlightWrap("number", highlight[self])
			else
				return highlightWrap(`number<{table.concat(limitsStr, ", ")}>`, highlight[self])
			end
		end,
	}
	return setmetatable(self :: any, Type) :: any
end

local PATTERN_REPLACEMENTS = { ["\r"] = "\\r", ["\n"] = "\\n", ["\t"] = "\\t" }

--- Creates a new GreenTea Type that matches string values.\
--- Optionally, you can specify a pattern, a length range, and whether the string must be utf8.\
--- NOTE: this supports both "byte length" and "grapheme length". Grapheme length is the number of visible
--- characters. In non-english languages, the number of bytes can be significantly higher than the number
--- of graphemes.\
--- When using graphemes limit, you should still set a (much-higher) bytes limit to prevent abuse, since
--- graphemes have no upper limit to their size. For this reason, this constructor will error if you
--- do not specify a bytes limit when using graphemes limit. If you really want infinite byte length, set
--- bytes to `[0, inf]`.
function GreenTea.string(limits: {
	pattern: string?,
	bytes: RangeInput__DARKLUA_TYPE_aW?,
	graphemes: RangeInput__DARKLUA_TYPE_aW?,
	unicode: boolean?,
}?): string
	local byteLengthRange = limits and limits.bytes and parseRange(limits.bytes)
	local graphemeLengthRange = limits and limits.graphemes and parseRange(limits.graphemes)

	if graphemeLengthRange and not byteLengthRange then
		error(
			"graphemes limit requires bytes limit. Graphemes have no upper limit on size, so if only graphemes limit is set, the byte limit is practically infinite. If you really want infinite byte length, set bytes to `[0, inf]`"
		)
	end

	if graphemeLengthRange then
		error(
			"graphemes limit is not supported on your platform (your platform does not support the utf8.graphemes function)"
		)
	end

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "string",
		string = {
			pattern = limits and limits.pattern,
			bytes = byteLengthRange,
			graphemes = graphemeLengthRange,
			unicode = limits and limits.unicode,
		},
		_matches = function(input: any)
			if typeof(input) ~= "string" then
				return Cause.err(self, input, "expected string, got $input")
			end

			if limits then
				if limits.unicode then
					if not isStringUnicode(input) then
						return Cause.err(self, input, "input is not unicode")
					end
				end
				if byteLengthRange and not checkRange(#input, byteLengthRange) then
					return Cause.err(
						self,
						input,
						`input length out of range (#input: {#input} from #{truncate(15, tostringLiteral(input))})`
					)
				end
				if limits.pattern and not string.match(input, limits.pattern) then
					return Cause.err(
						self,
						input,
						`input does not match pattern (input: {truncate(15, tostringLiteral(input))})`
					)
				end
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, _maxLineLength: number, _recurse: { [any]: any })
			if not limits then
				return highlightWrap("string", highlight[self])
			end

			local limitsStr = {}
			if limits.unicode then
				table.insert(limitsStr, "unicode")
			end
			if graphemeLengthRange then
				table.insert(limitsStr, `graphemes {displayRange(graphemeLengthRange)}`)
			end
			if byteLengthRange then
				table.insert(limitsStr, `bytes {displayRange(byteLengthRange)}`)
			end
			if limits.pattern then
				local pattern = string.gsub(limits.pattern, "[\r\n\t]", PATTERN_REPLACEMENTS)
				table.insert(limitsStr, `pattern "{pattern}"`)
			end

			if #limitsStr == 0 then
				return highlightWrap("string", highlight[self])
			else
				return highlightWrap(`string<{table.concat(limitsStr, ", ")}>`, highlight[self])
			end
		end,
	}
	return setmetatable(self :: any, Type) :: any
end

--- Creates a new GreenTea Type that matches any `typeof(value)` type.
function GreenTea.isTypeof<T>(typeName: string, _value: T?): T
	return newBasicType(typeName)()
end

--- Creates a new GreenTea Type that matches any `type(value)` type.
function GreenTea.isType<T>(typeName: string, _value: T?): T
	return newBasicType(typeName)()
end

--- @within GreenTea
--- @function types not listed here
--- A few methods are not listed in the docs so that they don't clutter with basic types.\
--- Here's a list: userdata, Vector2, vector, Vector3, CFrame, Color3, UDim, UDim2,
--- Ray, Rect, Region3, BrickColor, Font, Enum, EnumItem.\
--- For the most part, any Luau type you'd naturally write likely also exists under GreenTea.
--- Less common types are excluded (for now) to not clutter the library.
--- For the ones that don't exist, you can usually use `isTypeof` or `isType`.

local typePackCast: <Out...>(...any) -> Out...= function(...)
	return ...
end

--- Creates a new GreenTea Type that matches a repeating value.
function GreenTea.vararg<T>(
	type: T,
	options: {
		length: RangeInput__DARKLUA_TYPE_aW?,
	}?
): ...T
	local lengthRange = options and options.length and parseRange(options.length)
	local varargType: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(type :: any)

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "vararg",
		vararg = {
			type = varargType,
			length = lengthRange,
		},
		_matches = function(...: any)
			local errs: { { type: any, input: any?, message: string? } } = {}
			local hasErrs = false

			local input = table.pack(...)
			for index = input.n, 1, -1 do
				if input[index] == nil then
					input.n -= 1
				else
					break
				end
			end

			if lengthRange and not checkRange(input.n, lengthRange) then
				table.insert(errs, {
					type = self,
					input = table.pack(...),
					message = `expected input count to be within range {displayRange(lengthRange)}`,
				})
				return Cause.new(false, errs)
			end

			if varargType.kind == "any" or varargType.kind == "unknown" then
				return Cause.ok()
			end

			for index = 1, input.n do
				local cause = varargType._matches(input[index])
				if not cause.ok then
					table.move(cause.errs, 1, #cause.errs, #errs + 1, errs)
					hasErrs = true
				end
			end
			if hasErrs then
				table.insert(errs, 1, { type = self, input = table.pack(...) })
				return Cause.new(false, errs)
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			local result = `...{varargType._format(highlight, maxLineLength - 3, recurse)}`
			return highlightWrap(result, highlight[self])
		end,
	}
	return setmetatable(self :: TypeRaw__DARKLUA_TYPE_a0, Type) :: any
end

--[[
	The final argument gets expanded if it's a tuple.
	All prior arguments are simplified to only the first value if they're a tuple or a vararg.
	This matches the Luau typechecker's behavior.
]]
local function simplifyGtTuples<T...>(...: T...): T...
local args: { [number]: any, n: number } = table.pack(...)

	for index = 1, args.n do
		local value: any = args[index]
		if GreenTea.isGtType(value) then
			-- selene: allow(shadowing)
			local value: Type__DARKLUA_TYPE_a1 = value
			if value.tuple then
				if index == args.n then
					args[index] = nil
					table.move(value.tuple.contents, 1, #value.tuple.contents, index, args)
					args.n += #value.tuple.contents - 1
					if value.tuple.vararg then
						table.insert(args, value.tuple.vararg)
						args.n += 1
					end
				else
					args[index] = value.tuple.contents[1] or value.tuple.vararg or GreenTea.none()
				end
			elseif value.vararg then
				if index ~= args.n then
					args[index] = value.vararg.type
				end
			end
		end
	end

	return typePackCast(unpack(args, 1, args.n))
end

--- Creates a new GreenTea Type that matches a tuple of values.\
--- Specify the final value with GreenTea.vararg to match a repeating final value.\
--- This properly accepts a tuple as the final or only argument, so don't fear
--- passing a tuple into this by accident.
function GreenTea.tuple<T...>(...: T...): T...
local contents = table.pack(simplifyGtTuples(...))
	for index = 1, contents.n do
		if contents[index] == nil then
			error(
				"nil types are not allowed implicitly in tuples; specify explicitly or fix your arguments to not have nil"
			)
		end
		contents[index] = GreenTea.typeof(contents[index])
	end
	contents.n = nil :: any
	-- selene: allow(shadowing)
	local contents: { Type__DARKLUA_TYPE_a1 } = contents :: any

	local vararg: Type__DARKLUA_TYPE_a1?
	if contents[#contents] and contents[#contents].kind == "vararg" then
		vararg = contents[#contents]
		contents[#contents] = nil
	end

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "tuple",
		tuple = {
			contents = contents,
			vararg = vararg,
		},
		_matches = function(...: any)
			local errs = {}
			local hasErrs = false

			local input = table.pack(...)
			for index = input.n, 1, -1 do
				if input[index] == nil then
					input.n -= 1
				else
					break
				end
			end
			for index, gtType in contents do
				-- selene: allow(shadowing)
				local input = input[index]

				local cause = gtType._matches(input)
				if not cause.ok then
					table.move(cause.errs, 1, #cause.errs, #errs + 1, errs)
					hasErrs = true
				end
			end

			if hasErrs then
				table.insert(errs, 1, { type = self, input = newCauseTuple(...) })
				return Cause.new(false, errs)
			end

			if input.n <= #contents then
				return Cause.ok()
			end

			if not vararg then
				return Cause.errs({
					{ type = self, input = input[#contents + 1] },
					{
						type = self,
						input = newCauseTuple(...),
						message = `expected a tuple of {#contents} elements, got {input.n} elements from $input`,
					},
				})
			end

			return vararg._matches(select(#contents + 1, ...))
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			local formatted = {}
			for _index, expectedType in ipairs(contents) do
				local valueStr
				if expectedType._needsParens then
					valueStr = `({expectedType._format(highlight, maxLineLength - 4, recurse)})`
				else
					valueStr = expectedType._format(highlight, maxLineLength - 2, recurse)
				end
				table.insert(formatted, valueStr)
			end

			if vararg then
				table.insert(formatted, vararg._format(highlight, maxLineLength - 3, recurse))
			end

			local result = table.concat(formatted, ", ")
			if lineLengthOf(result) > maxLineLength or string.find(result, "\n", 1, true) then
				return highlightWrap(`(\n{tabFirst(table.concat(formatted, ",\n"))}\n)`, highlight[self])
			else
				return highlightWrap(`({table.concat(formatted, ", ")})`, highlight[self])
			end
		end,
	}

	return typePackCast(setmetatable(self :: any, Type))
end

--- Used for GreenTea.fn only. This is used to pass args to GreenTea.fn ergonomically.
function GreenTea.args<T...>(...: T...): (T...) -> ()
	return GreenTea.tuple(...) :: any
end

--- Used for GreenTea.fn only. This is used to pass returns to GreenTea.fn ergonomically.
function GreenTea.returns<T...>(...: T...): () -> T...
return GreenTea.tuple(...) :: any
end

--- Creates a new GreenTea Type that matches a function.\
--- This cannot perform any runtime checks on the function's args or returns.
--- The args and returns exist primarily to have an accurate Luau type.\
--- They _can_ be inspected at runtime with `type.fn.args` and `type.fn.returns`.\
--- If you're building a module that consumes GreenTea types, you can use
--- `type.fn.args` and `type.fn.returns` to run runtime typechecking yourself.
--- For example, if you were building a RemoteFunction wrapper, you could use
--- `type.fn.returns` to check that the client returned correct values.
function GreenTea.fn<Args..., Returns...>(args: (Args...) -> (), returns: () -> Returns...): (Args...) -> Returns...	-- where Luau wants to make this function return `(Args...) -> Returns..., Args...`

	-- selene: allow(shadowing)
	

local args: Type__DARKLUA_TYPE_a1 = args :: any
	-- selene: allow(shadowing)
	local returns: Type__DARKLUA_TYPE_a1 = returns :: any

	assert(GreenTea.isGtType(args), "args must be a GreenTea type. Use GreenTea.args to specify args.")
	assert(GreenTea.isGtType(returns), "returns must be a GreenTea type. Use GreenTea.returns returns.")

	assert(args.tuple, "args must be a GreenTea tuple type. Use GreenTea.args to specify args.")
	assert(returns.tuple, "returns must be a GreenTea tuple type. Use GreenTea.returns returns.")

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "function",
		fn = {
			args = args,
			returns = returns,
		},
		_matches = function(input: any)
			if typeof(input) ~= "function" then
				return Cause.err(self, input, "expected function")
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			local argsFormatted = {}
			for _index, argType in args.tuple.contents do
				table.insert(argsFormatted, argType._format(highlight, maxLineLength - 1, recurse))
			end
			if args.tuple.vararg then
				table.insert(argsFormatted, args.tuple.vararg._format(highlight, maxLineLength - 1, recurse))
			end

			local returnsFormatted = {}
			for _index, returnType in returns.tuple.contents do
				table.insert(returnsFormatted, returnType._format(highlight, maxLineLength - 1, recurse))
			end
			if returns.tuple.vararg then
				table.insert(returnsFormatted, returns.tuple.vararg._format(highlight, maxLineLength - 1, recurse))
			end

			local argsStr, returnsStr

			if #argsFormatted == 0 then
				argsStr = "() ->"
			else
				argsStr = `({table.concat(argsFormatted, ", ")}) ->`
				if lineLengthOf(argsStr) > SOFT_MAX_LINE_LENGTH or string.find(argsStr, "\n", 1, true) then
					argsStr = `(\n{tabFirst(table.concat(argsFormatted, ",\n"))}\n) ->`
				end
			end

			local finalItem = returns.tuple.vararg or returns.tuple.contents[#returns.tuple.contents]

			if #returnsFormatted == 0 then
				returnsStr = "()"
			elseif #returnsFormatted == 1 and not finalItem.__needsParens then
				returnsStr = returnsFormatted[1]
			else
				returnsStr = `({table.concat(returnsFormatted, ", ")})`
				if lineLengthOf(returnsStr) > SOFT_MAX_LINE_LENGTH or string.find(returnsStr, "\n", 1, true) then
					returnsStr = tabSecond(`({table.concat(returnsFormatted, ",\n")})`)
				end
			end

			local result = `{argsStr} {returnsStr}`
			if lineLengthOf(result) > maxLineLength or string.find(result, "\n", 1, true) then
				return highlightWrap(`{argsStr}\n{tabFirst(returnsStr)}`, highlight[self])
			else
				return highlightWrap(result, highlight[self])
			end
		end,
	}
	return setmetatable(self :: any, Type) :: any
end

--- Creates a new GreenTea Type that matches a function with any args and any returns.
function GreenTea.anyfn(): (...any) -> ...any
	return GreenTea.fn(
		GreenTea.args(GreenTea.vararg(GreenTea.any({ allowNil = true }))),
		GreenTea.returns(GreenTea.vararg(GreenTea.any({ allowNil = true })))
	) :: any
end

--- Creates a new GreenTea Type that "smuggles" a tuple as a single value by
--- packing it into the returns.\
--- This is useful for accepting GreenTea tuple types to a spot that only accepts a single value.
--- The actual returned type here is equivalent to
--- `GreenTea.fn(GreenTea.args(), GreenTea.returns(...))`
--- so some inspections is required at runtime to pull out the tuple:
--- `type.fn.returns` is the actual tuple value.\
--- With Luau typechecking, you can "unsmuggle" the tuple by doing
--- `typeof(smuggledTuple())` to get the tuple type.
function GreenTea.tuplePacked<T...>(...: T...): () -> T...
return GreenTea.fn(GreenTea.args(), GreenTea.returns(...)) :: any
end
--- Creates a new GreenTea Type that matches a table.\
--- The `contents` table should be a dictionary of string keys to types.\
--- An indexer can be provided with `{ [keyGreenTeaType] = valueType }`.\
--- This currently respects both `__iter` and `__index` on both the input
--- `contents` table and tables being checked against.\
--- Tables are non-strict by default. Extra values are allowed. If you'd
--- like to make a table strict, add an indexer that denies extra values, like
--- `[gt.any()] = gt.never()`.\
--- By default, array-like definitions do not check for holes. If you would like
--- to check for holes and ensure the array is contiguous, set array to true.\
--- If you'd like to enforce an item limit, specify it `count` the options table. This limits
--- the number of items found by the indexer. Items in the "struct portion" of the
--- table definition do not count. This is _not_ a #table check: the actual items
--- are counted one-by-one as we check them. This lets you also limit the number of items
--- in cases like dynamic dictionaries.\
--- `raw` allows for checking any key types as literally matching to values, including numbers
--- and other non-strings. This _will not_ appear correct as a Luau type; it is primarily
--- intended for compatibility with other runtime typechecking libraries.



function GreenTea.table<T>(
	contents: T,
	options: {
		array: boolean?,
		count: RangeInput__DARKLUA_TYPE_aW?,
		raw: boolean?,
	}?
): T
	local array: boolean? = options and options.array or nil
	local countRange = if options and options.count then parseRange(options.count) else nil

	local isRaw = options and options.raw or nil

	-- note: pairs is used to avaid the __iter metamethod
	local indexerKey: Type__DARKLUA_TYPE_a1?
	local indexerValue: Type__DARKLUA_TYPE_a1?
	local indexerValues: { Type__DARKLUA_TYPE_a1 } = {}
	local rawContents = {}
	for key, value in contents :: any do
		if typeof(key) == "table" and GreenTea.isGtType(key) then
			if indexerKey then
				error("Only one indexer can be specified")
			else
				indexerKey = GreenTea.typeof(key)
				indexerValue = GreenTea.typeof(value)
			end
		elseif isRaw then
			rawContents[key] = GreenTea.typeof(value)
		else
			if typeof(key) == "number" then
				if indexerKey then
					error("Only one indexer can be specified")
				end
				indexerKey = GreenTea.number() :: any
				table.insert(indexerValues, GreenTea.typeof(value))
			elseif typeof(key) == "string" then
				rawContents[key] = GreenTea.typeof(value)
			else
				error("Tables must be defined as arrays or dictionaries with string keys")
			end
		end
	end

	if #indexerValues > 0 then
		if #indexerValues == 1 then
			indexerValue = indexerValues[1]
		else
			-- NOTE: this case never happens presently due to the "Only one indexer can be specified" checks.
			indexerValue = (GreenTea :: any).union(table.unpack(indexerValues))
		end
	end

	if array and (not indexerKey or indexerKey.kind ~= "number") then
		error("If array is true, the table must have an indexer with number keys")
	end

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "table",
		table = {
			contents = rawContents,
			indexer = indexerKey and {
				key = indexerKey,
				value = indexerValue,
			} or nil,

			array = array :: boolean?,
			count = countRange,

			raw = isRaw,
		},
		_matches = function(input: any)
			if typeof(input) ~= "table" then
				return Cause.err(self, input, "expected table")
			end

			local checked = {}

			local maxN = 0
			local count = 0

			local cause

			for key, expectedType in rawContents do
				local value = input[key]

				cause = expectedType._matches(value)
				if not cause.ok then
					return Cause.extendErr(cause, self, input)
				end

				checked[key] = true
			end

			for key, value in input do
				if checked[key] then
					continue
				end

				local expectedType = rawContents[key]
				if expectedType then
					cause = expectedType._matches(value)
					if not cause.ok then
						return Cause.extendErr(cause, self, input)
					end
				else
					if indexerKey then
						assert(indexerValue, "analysis hint")

						count += 1
						if countRange and not checkRange(count, countRange) then
							return Cause.err(
								self,
								input,
								`expected number of items to be in range {displayRange(countRange)}, but we saw {count} (or more) items`
							)
						end
						cause = indexerKey._matches(key)
						if not cause.ok then
							return Cause.extendErr(cause, self, input)
						end
						cause = indexerValue._matches(value)
						if not cause.ok then
							return Cause.extendErr(cause, self, input)
						end
						if typeof(key) == "number" then
							maxN = math.max(maxN, key)
							if array then
								if key < 1 then
									return Cause.err(
										self,
										input,
										`key {key} is less than 1, but we expected a contiguous array`
									)
								elseif math.floor(key) ~= key then
									return Cause.err(
										self,
										input,
										`key {key} is not an integer, but we expected a contiguous array`
									)
								elseif key ~= key then
									return Cause.err(
										self,
										input,
										`key {key} is NaN, but we expected a contiguous array`
									)
								end
							end
						end
					end
				end
			end

			if countRange and not checkRange(count, countRange) then
				return Cause.err(
					self,
					input,
					`expected number of items to be in range {displayRange(countRange)}, but we saw only {count} items`
				)
			end

			if array and count ~= maxN then
				assert(indexerValue, "analysis hint")

				cause = indexerValue._matches(nil)
				if not cause.ok then
					return Cause.extendErr(
						cause,
						self,
						input,
						`expected contiguous array, but we saw only {count} items when the max index was {maxN}`
					)
				end
			end

			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			local items = {}
			if array then
				table.insert(items, `@array`)
			end
			if countRange then
				table.insert(items, `@count {displayRange(countRange)}`)
			end
			if indexerKey then
				assert(indexerValue, "analysis hint")
				if indexerKey.kind == "number" then
					table.insert(items, indexerValue._format(highlight, maxLineLength - 1, recurse))
				else
					local keyStr = indexerKey._format(highlight, maxLineLength - 3, recurse)
					local valueStr = indexerValue._format(highlight, maxLineLength - 1, recurse)
					local indexerStr = `[{keyStr}]: {valueStr}`
					if lineLengthOf(indexerStr) > maxLineLength then
						indexerStr = `[{keyStr}]:\n{valueStr}`
					end
					table.insert(items, indexerStr)
				end
			end
			for key: any, value in rawContents do
				local keyStr = tostring(key)
				local valueStr = value._format(highlight, maxLineLength - 3, recurse)
				local itemStr = `{keyStr}: {valueStr}`
				if lineLengthOf(itemStr) > maxLineLength then
					itemStr = `{keyStr}: {valueStr}`
				end
				table.insert(items, itemStr)
			end

			if #items == 0 then
				return highlightWrap("{}", highlight[self])
			end

			local leftCurly, rightCurly = "{", "}"

			local result = `{leftCurly} {table.concat(items, ", ")} {rightCurly}`
			if lineLengthOf(result) > maxLineLength or string.find(result, "\n", 1, true) then
				return highlightWrap(
					`{leftCurly}\n{tabFirst(table.concat(items, ",\n"))}\n{rightCurly}`,
					highlight[self]
				)
			else
				return highlightWrap(result, highlight[self])
			end
		end,
	}
	return setmetatable(self, Type) :: any
end

GreenTea.struct = GreenTea.table

function GreenTea.anyTable(options: {
	count: RangeInput__DARKLUA_TYPE_aW?,
}?)
	return GreenTea.table({ [GreenTea.any()] = GreenTea.any() }, {
		count = options and options.count,
	})
end

--- Creates a new GreenTea Type that matches an array of values.\
--- Convenience function that calls GreenTea.table internally.
function GreenTea.array<T>(
	value: T,
	options: {
		count: RangeInput__DARKLUA_TYPE_aW?,
	}?
): { T }
	return GreenTea.table({ GreenTea.typeof(value) }, {
		array = true,
		count = options and options.count,
	})
end

--- Creates a new GreenTea Type that matches a dictionary of values.\
--- Convenience function that calls GreenTea.table internally.
function GreenTea.dictionary<K, V>(
	key: K,
	value: V,
	options: {
		count: RangeInput__DARKLUA_TYPE_aW?,
	}?
): { [K]: V }
	return GreenTea.table({ [GreenTea.typeof(key)] = GreenTea.typeof(value) }, {
		count = options and options.count,
	})
end








local union: UnionType__DARKLUA_TYPE_a4 = function<T>(...: T): ...T
	local types: { [number]: any, n: number } = table.pack(...)
	for index = types.n, 1, -1 do
		if types[index] == nil then
			types.n -= 1
		else
			break
		end
	end

	local nilTypes, nonnilTypes = {}, {}
	for index = 1, types.n do
		if types[index] == nil then
			error("implicit nil type not allowed in union; specify explicitly or fix your arguments to not have nil")
		end
		local value: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(types[index])
		types[index] = value
		if value.basic and (value.basic.type == "nil" or value.basic.typeof == "nil") then
			table.insert(nilTypes, value)
		else
			table.insert(nonnilTypes, value)
		end
	end
	-- selene: allow(shadowing)
	local types: { any } = types;
	(types :: any).n = nil

	assert(#types > 0, "union must have at least one type")

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "union",
		union = {
			contents = types,
			optional = #nilTypes > 0,
		},
		_needsParens = true,
		_matches = function(input: any)
			local errs = {}
			for _k, expectedType: any in types do
				local cause = expectedType._matches(input)
				if cause.ok then
					return cause
				else
					table.move(cause.errs, 1, #cause.errs, #errs + 1, errs)
				end
			end
			table.insert(errs, 1, { type = self, input = input, message = "input did not match any union member" })
			return Cause.errs(errs)
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			if #nonnilTypes == 0 then
				return "nil"
			elseif #nonnilTypes == 1 then
				if #nilTypes > 0 then
					local optional = nonnilTypes[1]

					local result
					if optional._needsParens then
						result = `({optional._format(highlight, maxLineLength - 3, recurse)})?`
					else
						result = `{optional._format(highlight, maxLineLength - 1, recurse)}?`
					end

					return highlightWrap(result, highlight[self])
				else
					return highlightWrap(nonnilTypes[1]._format(highlight, maxLineLength, recurse), highlight[self])
				end
			end

			local formatted = {}
			for _, expectedType: any in types do
				local valueStr
				if expectedType._needsParens then
					valueStr = `({expectedType._format(highlight, maxLineLength - 4, recurse)})`
				else
					valueStr = expectedType._format(highlight, maxLineLength - 2, recurse)
				end
				table.insert(formatted, valueStr)
			end

			local result = table.concat(formatted, " | ")
			if lineLengthOf(result) > maxLineLength or string.find(result, "\n", 1, true) then
				return highlightWrap(
					formatted[1] .. tabFirst("\n| " .. table.concat(formatted, "\n| ", 2)),
					highlight[self]
				)
			else
				return highlightWrap(result, highlight[self])
			end
		end,
	}
	return setmetatable(self, Type) :: any
end :: any

--- @function union
--- @within GreenTea
--- @param ... T...
--- @return T...
--- Creates a new GreenTea Type that matches a union of types.\
--- This is analogous to the Luau `type1 | type2 | ...` syntax.\
--- This has convenient type definitions for up to 5 input types.\
--- When specifying more then 5 input types, you will have to typecast the
--- first item to a Luau type union in order to get correct types.

GreenTea.union = union








local intersection: IntersectionType__DARKLUA_TYPE_a5 = function<T>(...: T): ...T
	local types = table.pack(...)
	for index = types.n, 1, -1 do
		if types[index] == nil then
			types.n -= 1
		else
			break
		end
	end

	for index = 1, types.n do
		if types[index] == nil then
			error(
				"implicit nil type not allowed in intersection; specify explicitly or fix your arguments to not have nil"
			)
		end
		types[index] = GreenTea.typeof(types[index])
	end
	-- selene: allow(shadowing)
	local types: { any } = types;
	(types :: any).n = nil

	assert(#types > 0, "intersection must have at least one type")

	local self: TypeRaw__DARKLUA_TYPE_a0
	self = {
		kind = "intersection",
		intersection = {
			contents = types,
		},
		_needsParens = true,
		_matches = function(input: any)
			local errs = {}
			local hasErrs = false
			for _, expectedType: any in types do
				local cause = expectedType._matches(input)
				if not cause.ok then
					hasErrs = true
					table.move(cause.errs, 1, #cause.errs, #errs + 1, errs)
				end
			end
			if hasErrs then
				table.insert(
					errs,
					1,
					{ type = self, input = input, message = "input did not match all intersection members" }
				)
				return Cause.errs(errs)
			end
			return Cause.ok()
		end,
		_format = function(highlight: { [any]: string }, maxLineLength: number, recurse: { [any]: any })
			if recurse[self] then
				return "<cyclic>"
			end
			recurse[self] = true

			if #types == 0 then
				return "()"
			elseif #types == 1 then
				return highlightWrap(types[1]._format(highlight, maxLineLength, recurse), highlight[self])
			end

			local formatted = {}
			for _, expectedType: any in types do
				local valueStr
				if expectedType._needsParens then
					valueStr = `({expectedType._format(highlight, maxLineLength - 4, recurse)})`
				else
					valueStr = expectedType._format(highlight, maxLineLength - 2, recurse)
				end
				table.insert(formatted, valueStr)
			end

			local result = table.concat(formatted, " & ")
			if lineLengthOf(result) > maxLineLength or string.find(result, "\n", 1, true) then
				return highlightWrap(
					formatted[1] .. tabFirst("\n& " .. table.concat(formatted, "\n& ", 2)),
					highlight[self]
				)
			else
				return highlightWrap(result, highlight[self])
			end
		end,
	}
	return setmetatable(self, Type) :: any
end :: any

--- @function intersection
--- @within GreenTea
--- @param ... T...
--- @return T...
--- Creates a new GreenTea Type that matches an intersection of types.\
--- This is analogous to the Luau `type1 & type2 & ...` syntax.\
--- This has convenient type definitions for up to 5 input types.\
--- When specifying more then 5 input types, you will have to typecast the
--- first item to a Luau type intersection in order to get correct types.

GreenTea.intersection = intersection

--- Creates a new GreenTea Type that makes a value optionally,
--- like `type?` or `type | nil` in Luau types.
function GreenTea.optional<T>(value: T): T?
	return GreenTea.union(value :: T?, GreenTea.none()) :: any
end

GreenTea.oneOf = GreenTea.union

GreenTea.allOf = GreenTea.intersection

GreenTea.opt = GreenTea.optional

--- Creates a new GreenTea Type matching the inferred type of `value`.\
--- A runtime, this passes tables to `GreenTea.table`, functions to `GreenTea.fn`, and so on.\
--- This results in a runtime-inferred type roughly equivalent to the Luau typechecker's inferred types.
function GreenTea.typeof<T>(value: T, recursionCheck: { [any]: any }?): T
	if GreenTea.isGtType(value) then
		return value
	end
	if greenteaConstructorsSet[value] then
		local name = greenteaConstructorsSet[value]
		error(
			`Attempt to use a GreenTea constructor without calling it: you used {name}; did you mean to use {name}() instead?`
		)
	end

	-- selene: allow(shadowing)
	local recursionCheck = recursionCheck or {} :: typeof(assert(recursionCheck, ""))

	if typeof(value) == "table" then
		local newTable = {}
		for key, subValue in pairs(value :: any) do
			if recursionCheck[subValue] then
				newTable[key] = recursionCheck[subValue]
			end
			newTable[key] = GreenTea.typeof(subValue, recursionCheck)
		end
		if typeof(getmetatable(value)) == "table" then
			setmetatable(newTable :: any, getmetatable(value) :: any)
		end
		return GreenTea.table(newTable) :: any
	elseif typeof(value) == "function" then
		return GreenTea.anyfn() :: any
	elseif typeof(value) == "string" then
		return GreenTea.string() :: any
	elseif typeof(value) == "number" then
		return GreenTea.number() :: any
	end

	return GreenTea.isTypeof(typeof(value), value) :: any
end

--- Typecasts a value to a GreenTea type.\
--- At runtime this will error if the passed-in type is _not_ a GreenTea type.\
--- This exists as a convenience function because `type :: GreenTea.Type` is usually
--- not possible without an any cast like `(type :: any) :: GreenTea.Type`.\
--- \
--- **Usually, you'll want to use `GreenTea.build` when making GreenTea types.**
--- _`GreenTea.typecast` is specifically made for when you're doing tricky stuff with GreenTea types._
function GreenTea.typecast(value: any): Type__DARKLUA_TYPE_a1
	assert(GreenTea.isGtType(value), "value must be a GreenTea type")

	return value
end

GreenTea.asGreenTeaType = GreenTea.typecast
GreenTea.asGtType = GreenTea.typecast

local function castTuple<T...>(...: any): T...
return ...
end

-- This whole bit of acrobatics around this BuiltType table only exists so that
-- Luau LSP picks up the docs for the `:type()` method.
local BuiltType = {}

-- We use a different comment style here so that moonwave does not pick up this
-- comment and complain about that lack of BuiltType class definition.
--[[
In type definitions via `typeof(Type.type())`, returns the Luau type this
GreenTea type represents.\
At runtime, returns self. This allows you to compose complex GreenTea types
by passing GreenTea.type() into a GreenTea constructor.
]]
function BuiltType.type<T...>(self: { __getType: () -> T...}): T...
return castTuple(self)
end

--- Typecasts a value to be a GreenTea type, with the type stored under the `type`
--- key so you can get the type with `typeof(result.type())`\
--- \
--- **This is the preferred way to build a GreenTea type for typical use.**


function GreenTea.build<T...>(...: T...): BuiltType__DARKLUA_TYPE_a6<T...>
	local gtType: any

	local isTuple = select("#", ...) > 1

	-- Only treat it as a tuple if there are actually multiple values
	if isTuple then
		isTuple = false
		for index = 2, select("#", ...) do
			if select(index, ...) ~= nil then
				isTuple = true
				break
			end
		end
	end

	if isTuple then
		gtType = GreenTea.tuple(...)
	else
		gtType = GreenTea.typeof((castTuple(...)))
	end

	gtType.type = function(_self: Type__DARKLUA_TYPE_a1)
		return gtType
	end
	return gtType
end

--- Adds user-specified metadata to a type.\
--- Each key/value pair is added to the type's `meta` table.
--- This is a shallow merge: any matching key/value pair will be overwritten,
--- and all other key/value pairs will be kept as-is.
function GreenTea.meta<T>(gtType: T, meta: { [string]: any }): T
	-- selene: allow(shadowing)
	local gtType: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(gtType) :: any

	gtType.meta = gtType.meta or {}
	assert(gtType.meta, "analysis hint")

	for key, value in meta do
		gtType.meta[key] = value
	end

	return gtType :: any
end

--- Wraps a function with type asserts for its input args and returns.\
--- For example:
--- ```lua
--- gt.wrapFn(
---     gt.fn(
---         gt.args(gt.string(), gt.number()),
---         gt.returns(gt.number())
---     ),
---     function(arg1, arg2)
---         --- Luau will properly infer arg types via above definition
---         return 5
---     end
--- )
--- ```
--- Notes:
--- * If you've stored the GreenTea type in a variable, and "built" it with `GreenTea.build`,
---   then you will need to use `gtType:type()` here:
---   ```lua
---   local gtType = GreenTea.build(gt.string(), gt.number())
---   gt.wrapFn(gtType:type(), function(arg1, arg2)
---       return 5
---   end)
---   ```
--- * If you're trying to add asserts to an unknown or dynamically-provided function, you may need to cast it to `any` first:
---   ```lua
---   gt.wrapFn(
---       gt.fn(
---           gt.args(gt.string(), gt.number()),
---           gt.returns(gt.number())
---       ),
---       someFunction :: any
---   )
---   ```
function GreenTea.wrapFn<T>(gtType: T, fn: T): T
	-- selene: allow(shadowing)
	local gtType: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(gtType) :: any

	assert(typeof(fn) == "function", "fn must be a function")
	assert(gtType.fn ~= nil, "gtType must be a GreenTea.fn type")

	return function(...: any)
		gtType.fn.args:assert(...)

		return gtType.fn.returns:assert(fn(...))
	end :: any
end

--- Wraps a function with type asserts for its input args only.\
--- See `GreenTea.wrapFn` for more information.
function GreenTea.wrapFnArgs<T>(gtType: T, fn: T): T
	-- selene: allow(shadowing)
	local gtType: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(gtType) :: any

	assert(typeof(fn) == "function", "fn must be a function")
	assert(gtType.fn ~= nil, "gtType must be a GreenTea.fn type")

	return function(...: any)
		gtType.fn.args:assert(...)

		return fn(...)
	end :: any
end

--- Wraps a function with type asserts for its returns only.\
--- See `GreenTea.wrapFn` for more information.
function GreenTea.wrapFnReturns<T>(gtType: T, fn: T): T
	-- selene: allow(shadowing)
	local gtType: Type__DARKLUA_TYPE_a1 = GreenTea.typeof(gtType) :: any

	assert(typeof(fn) == "function", "fn must be a function")
	assert(gtType.fn ~= nil, "gtType must be a GreenTea.fn type")

	return function(...: any)
		return gtType.fn.returns:assert(fn(...))
	end :: any
end

return GreenTea
end function __DARKLUA_BUNDLE_MODULES.aB():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aB if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aB=v end return v.c end end do local function __modImpl()
local GreenTea = __DARKLUA_BUNDLE_MODULES.aB()





local export = {}

export.isGreenTeaType = GreenTea.isGreenTeaType
export.isGtType = GreenTea.isGtType

export.any = GreenTea.any
export.unknown = GreenTea.unknown
export.never = GreenTea.never

export.boolean = GreenTea.boolean
export.bool = GreenTea.bool

export.Instance = GreenTea.Instance

export.coroutine = GreenTea.coroutine
export.thread = GreenTea.thread

export.buffer = GreenTea.buffer

export.userdata = GreenTea.userdata

export.none = GreenTea.none

export.literal = GreenTea.literal

export.withCustom = GreenTea.withCustom
export.custom = GreenTea.custom

export.number = GreenTea.number

export.string = GreenTea.string

export.isTypeof = GreenTea.isTypeof
export.isType = GreenTea.isType

export.vararg = GreenTea.vararg
export.tuple = GreenTea.tuple

export.args = GreenTea.args
export.returns = GreenTea.returns
export.fn = GreenTea.fn
export.anyfn = GreenTea.anyfn

export.tuplePacked = GreenTea.tuplePacked

export.table = GreenTea.table
export.struct = GreenTea.struct

export.anyTable = GreenTea.anyTable
export.array = GreenTea.array
export.dictionary = GreenTea.dictionary

export.union = GreenTea.union
export.oneOf = GreenTea.oneOf

export.intersection = GreenTea.intersection
export.allOf = GreenTea.allOf

export.optional = GreenTea.optional
export.opt = GreenTea.opt

export.typeof = GreenTea.typeof

export.typecast = GreenTea.typecast
export.asGreenTeaType = GreenTea.asGreenTeaType
export.asGtType = GreenTea.asGtType

export.build = GreenTea.build

export.meta = GreenTea.meta

export.wrapFn = GreenTea.wrapFn
export.wrapFnArgs = GreenTea.wrapFnArgs
export.wrapFnReturns = GreenTea.wrapFnReturns

table.freeze(export)
table.freeze(GreenTea.__Cause)
table.freeze(GreenTea.__Type)

for key, value in export do
	GreenTea.__greenteaConstructorsSet[value] = `GreenTea.{key}`
end

return export
end function __DARKLUA_BUNDLE_MODULES.aC():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aC if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aC=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aC()



return module end function __DARKLUA_BUNDLE_MODULES.aD():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aD if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aD=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path
local gt = __DARKLUA_BUNDLE_MODULES.aD()



local PathType = gt.build(gt.custom(luauPath.Path.is, "Path") :: Path__DARKLUA_TYPE_aS)
local Components = getmetatable(Path.from("a"):components() :: any).__index :: Components__DARKLUA_TYPE_bd & {
	new: (path: string, prefix: any?, hasPhysicalRoot: boolean) -> Components__DARKLUA_TYPE_bd,
	is: (value: unknown) -> boolean,
}
local ComponentsType = gt.build(gt.custom(Components.is, "Components") :: Components__DARKLUA_TYPE_bd)
local AsPathType = gt.build(gt.union(gt.string(), PathType:type(), ComponentsType:type()))
local ContentsType = gt.build(gt.union(gt.string(), gt.buffer()))
local booleanType = gt.build(gt.boolean())
local stringType = gt.build(gt.string())
local optionalBooleanType = gt.build(gt.opt(gt.boolean()))
local arrayOfStringType = gt.build(gt.array(gt.string()))

--[=[
	@class Path

	A `Path` class from https://github.com/seaofvoices/luau-path
]=]

--[=[
	@within Path
	@type AsPath string | Path | Components

	A type that can be used as a path-like value.
]=]

--[=[
	@within Path
	@function new

	Creates a new `Path` instance.

	@param path string -- The path string
	@return Path -- A new `Path` instance
]=]

--[=[
	@within Path
	@function from

	Creates a new `Path` instance from a path-like value.

	@param path AsPath -- The path-like value
	@return Path -- A new `Path` instance
]=]

--[=[
	@within Path
	@function is

	Checks if a value is a `Path` instance.

	@param value unknown -- The value to check
	@return boolean -- Whether the value is a `Path` instance
]=]





return {
	PathType = PathType,
	Components = Components,
	ComponentsType = ComponentsType,
	AsPathType = AsPathType,
	ContentsType = ContentsType,
	booleanType = booleanType,
	stringType = stringType,
	optionalBooleanType = optionalBooleanType,
	arrayOfStringType = arrayOfStringType,
}
end function __DARKLUA_BUNDLE_MODULES.aE():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aE if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aE=v end return v.c end end do local function __modImpl()
local types = __DARKLUA_BUNDLE_MODULES.aE()
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path




















local PeekableComponents = {} :: PeekableComponentsImpl__DARKLUA_TYPE_bl
PeekableComponents.__index = PeekableComponents

function PeekableComponents.next(self)
	if self.peeked then
		local peeked = self.peeked
		self.peeked = false
		return peeked
	end
	return self.iter:next()
end

function PeekableComponents.peek(self)
	if not self.peeked then
		self.peeked = self.iter:next() or false
	end
	return self.peeked or nil
end

local function peekable(iter: Components__DARKLUA_TYPE_bh): PeekableComponents__DARKLUA_TYPE_bk
	return setmetatable({
		iter = iter,
		peeked = false :: false,
	}, PeekableComponents)
end

--[=[
	@within pathfs
	@function normalize

	Normalizes paths similarly to canonicalize, but without performing I/O.

	This is like Python's `os.path.normpath`.

	*Original implementation/source credit goes to [normalize-path](https://docs.rs/normalize-path/0.2.1/src/normalize_path/lib.rs.html#30).*

	Normalize a path without performing I/O.

	All redundant separator and up-level references are collapsed.

	However, this does not resolve links.

	### Example
	```lua
	local path = pathfs.normalize("./path/to/./file") -- "path/to/file"
	```

	@param path AsPath -- The path to normalize
	@return Path -- The normalized path
]=]
return function(path: AsPath__DARKLUA_TYPE_bi): Path__DARKLUA_TYPE_bj
	-- selene: allow(shadowing)
	local path = Path.from(path)
	local components = peekable(path:components())
	local ret
	local c = components:peek()
	if c and c.type == "prefix" then
		local buf = Path.new(c:toString())
		components:next()
		ret = buf
	else
		ret = Path.new("")
	end

	local component = components:next()
	while component do
		if component.type == "prefix" then
			error("unreachable")
		elseif component.type == "rootDir" or component.type == "normal" then
			ret:push(component:toString())
		elseif component.type == "parentDir" then
			ret:pop()
		else
			error("Unknown component type: " .. tostring(component.type))
		end
		component = components:next()
	end

	return ret
end
end function __DARKLUA_BUNDLE_MODULES.aF():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aF if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aF=v end return v.c end end do local function __modImpl()
local types = __DARKLUA_BUNDLE_MODULES.aE()
local AsPathType = types.AsPathType
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path
local process = require("@lune/process")
local normalizePath = __DARKLUA_BUNDLE_MODULES.aF()

--[=[
	@class vfs
	@private
]=]



local vfs = {}

local currentDir: Path__DARKLUA_TYPE_bm?

local cwd = normalizePath(process.cwd)

function vfs.createPath(path: AsPath__DARKLUA_TYPE_bn): Path__DARKLUA_TYPE_bm
	-- selene: allow(shadowing)
	local path = Path.from(path)
	if currentDir and not path:isAbsolute() then
		return currentDir:join(path)
	end
	return path
end

function vfs.asPathToString(asPath: AsPath__DARKLUA_TYPE_bn): string
	if type(asPath) == "string" then
		return asPath
	end
	return vfs.createPath(asPath):toString()
end

--[=[
	@within vfs

	Sets the current directory path virtually.

	An error will be thrown in the following situations:

	* Given path is not a relative path.
]=]
function vfs.setCurrentDir(path: AsPath__DARKLUA_TYPE_bn)
	assert(AsPathType(path))

	local newCurrentDir: Path__DARKLUA_TYPE_bm = Path.from(vfs.asPathToString(path))
	if not newCurrentDir:isRelative() then
		error("Current path must be a relative path")
	end
	currentDir = newCurrentDir
	cwd = normalizePath(Path.from(process.cwd):join(newCurrentDir))
end

--[=[
	@within pathfs

	Returns the current working directory as an absolute path.

	@return Path -- The current working directory
]=]
function vfs.cwd(): Path__DARKLUA_TYPE_bm
	return cwd
end

return vfs
end function __DARKLUA_BUNDLE_MODULES.aG():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aG if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aG=v end return v.c end end do local function __modImpl()
local luneFileSystem = require("@lune/fs")
local gt = __DARKLUA_BUNDLE_MODULES.aD()
local vfs = __DARKLUA_BUNDLE_MODULES.aG()
local asPathToString = vfs.asPathToString
local types = __DARKLUA_BUNDLE_MODULES.aE()

local AsPathType = types.AsPathType
local booleanType = types.booleanType
local stringType = types.stringType
local ContentsType = types.ContentsType
local arrayOfStringType = types.arrayOfStringType

--[=[
	@class fs

	`require("@lune/fs")` compat module

	### Example
	```lua
	local fs = require("path/to/pathfs").fs

	fs.readFile("path/to/file")
	fs.writeFile("path/to/file", "content")
	```
]=]
local fs = {}

local overwriteOrOptionsType = gt.build(gt.any({ allowNil = true }) :: (luneFileSystem.WriteOptions | boolean)?)
--[=[
	@within fs

	Copies a file or directory recursively to a new path.

	Throws an error if a file or directory already exists at the target path.
	This can be bypassed by passing `true` as the third argument, or a dictionary of options.
	Refer to the documentation for `WriteOptions` for specific option keys and their values.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `from` or write at `to`.
	* Some other I/O error occurred.

	@param from -- The path to copy from
	@param to -- The path to copy to
	@param overwriteOrOptions -- Options for the target path, such as if should be overwritten if it already exists
]=]
function fs.copy(
	from: typeof(AsPathType:type()),
	to: typeof(AsPathType:type()),
	overwriteOrOptions: typeof(overwriteOrOptionsType:type())
)
	assert(AsPathType(from))
	assert(AsPathType(to))
	assert(overwriteOrOptionsType(overwriteOrOptions))

	return luneFileSystem.copy(asPathToString(from), asPathToString(to), overwriteOrOptions)
end

--[=[
	@within fs
	@tag must_use

	Checks if a given path is a directory.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param dirPath -- The directory path to check
	@return boolean -- If the path is a directory or not
]=]
function fs.isDir(dirPath: typeof(AsPathType:type())): typeof(booleanType:type())
	assert(AsPathType(dirPath))

	return luneFileSystem.isDir(asPathToString(dirPath))
end

--[=[
	@within fs
	@tag must_use

	Checks if a given path is a file.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param filePath -- The file path to check
	@return boolean -- If the path is a file or not
]=]
function fs.isFile(filePath: typeof(AsPathType:type())): typeof(booleanType:type())
	assert(AsPathType(filePath))

	return luneFileSystem.isFile(asPathToString(filePath))
end

--[=[
	@within fs
	@tag must_use

	Gets metadata for the given path.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `path`.
	* Some other I/O error occurred.

	@param path -- The path to get metadata for
	@return Metadata -- Metadata for the path
]=]
function fs.metadata(path: typeof(AsPathType:type())): luneFileSystem.Metadata
	assert(AsPathType(path))

	return luneFileSystem.metadata(asPathToString(path))
end

--[=[
	@within fs

	Moves a file or directory to a new path.

	Throws an error if a file or directory already exists at the target path.
	This can be bypassed by passing `true` as the third argument, or a dictionary of options.
	Refer to the documentation for `WriteOptions` for specific option keys and their values.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at `from` or write at `to`.
	* The new path exists on a different mount point.
	* Some other I/O error occurred.

	@param from -- The path to move from
	@param to -- The path to move to
	@param overwriteOrOptions -- Options for the target path, such as if should be overwritten if it already exists
]=]
function fs.move(
	from: typeof(AsPathType:type()),
	to: typeof(AsPathType:type()),
	overwriteOrOptions: typeof(overwriteOrOptionsType:type())
)
	assert(AsPathType(from))
	assert(AsPathType(to))
	assert(overwriteOrOptionsType(overwriteOrOptions))

	return luneFileSystem.move(asPathToString(from), asPathToString(to), overwriteOrOptions)
end

--[=[
	@within fs
	@tag must_use

	Reads entries in a directory at `path`.

	An error will be thrown in the following situations:

	* `path` does not point to an existing directory.
	* The current process lacks permissions to read the contents of the directory.
	* Some other I/O error occurred.

	@param dirPath -- The directory path to search in
	@return {string} -- A list of files & directories found
]=]
function fs.readDir(dirPath: typeof(AsPathType:type())): typeof(arrayOfStringType:type())
	assert(AsPathType(dirPath))

	return luneFileSystem.readDir(asPathToString(dirPath))
end

--[=[
	@within fs
	@tag must_use

	Reads a file at `path`.

	An error will be thrown in the following situations:

	* `path` does not point to an existing file.
	* The current process lacks permissions to read the file.
	* Some other I/O error occurred.

	@param filePath -- The path to the file to read
	@return string -- The contents of the file
]=]
function fs.readFile(filePath: typeof(AsPathType:type())): typeof(stringType:type())
	assert(AsPathType(filePath))

	return luneFileSystem.readFile(asPathToString(filePath))
end

--[=[
	@within fs

	Removes a directory and all of its contents.

	An error will be thrown in the following situations:

	* `path` is not an existing and empty directory.
	* The current process lacks permissions to remove the directory.
	* Some other I/O error occurred.

	@param path -- The directory to remove
]=]
function fs.removeDir(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.removeDir(asPathToString(path))
end

--[=[
	@within fs

	Removes a file.

	An error will be thrown in the following situations:

	* `path` does not point to an existing file.
	* The current process lacks permissions to remove the file.
	* Some other I/O error occurred.

	@param path -- The file to remove
]=]
function fs.removeFile(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.removeFile(asPathToString(path))
end

--[=[
	@within fs

	Writes to a file at `path`.

	An error will be thrown in the following situations:

	* The file's parent directory does not exist.
	* The current process lacks permissions to write to the file.
	* Some other I/O error occurred.

	@param path -- The path of the file
	@param contents -- The contents of the file
]=]
function fs.writeFile(path: typeof(AsPathType:type()), contents: typeof(ContentsType:type()))
	assert(AsPathType(path))
	assert(ContentsType(contents))

	return luneFileSystem.writeFile(asPathToString(path), contents)
end

--[=[
	@within fs

	Creates a directory and its parent directories if they are missing.

	An error will be thrown in the following situations:

	* `path` already points to an existing file or directory.
	* The current process lacks permissions to create the directory or its missing parents.
	* Some other I/O error occurred.

	@param path -- The directory to create
]=]
function fs.writeDir(path: typeof(AsPathType:type()))
	assert(AsPathType(path))

	return luneFileSystem.writeDir(asPathToString(path))
end

return fs
end function __DARKLUA_BUNDLE_MODULES.aH():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aH if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aH=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aH()
local types = __DARKLUA_BUNDLE_MODULES.aE()

local PathType = types.PathType
local AsPathType = types.AsPathType
local optionalBooleanType = types.optionalBooleanType
local arrayOfStringType = types.arrayOfStringType
local booleanType = types.booleanType

--[=[
	@class DirectoryPath

	Represents a directory path.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	dirPath:removeDir()
	```
]=]




















local DirectoryPath = {} :: DirectoryPathImpl__DARKLUA_TYPE_bp
DirectoryPath.__index = DirectoryPath
--[=[
	@within DirectoryPath
	@prop path Path
	The underlying `Path` instance.
]=]

--[=[
	@within DirectoryPath

	Returns a string representation of the `DirectoryPath` instance.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	print(dirPath) -- Output: DirectoryPath<path/to/dir>
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@return string -- A string representation of the DirectoryPath instance
]=]
function DirectoryPath.__tostring(self)
	assert(PathType(self.path))

	return `DirectoryPath<{self.path}>`
end

--[=[
	@within DirectoryPath

	Creates a new `DirectoryPath` instance.

	@param dirPath AsPath -- The directory path
	@return DirectoryPath -- A new `DirectoryPath` instance
]=]
function DirectoryPath.new(dirPath)
	assert(AsPathType(dirPath))

	return setmetatable({
		path = Path.from(dirPath),
	}, DirectoryPath)
end

--[=[
	@within DirectoryPath

	Creates a new `DirectoryPath` instance from an existing directory.

	An error will be thrown if the directory does not exist.

	@param dirPath AsPath -- The directory path
	@return DirectoryPath -- A new `DirectoryPath` instance
]=]
function DirectoryPath.fromExisting(dirPath)
	assert(AsPathType(dirPath))

	if not fs.isDir(dirPath) then
		error(`There is no directory at that path({dirPath})`)
	end

	return setmetatable({
		path = Path.from(dirPath),
	}, DirectoryPath)
end

--[=[
	@within DirectoryPath

	Writes the directory to the filesystem if it does not already exist.

	An error will be thrown in the following situations:

	* A file already exists at the directory path.
	* The current process lacks permissions to write the directory.
	* Some other I/O error occurred.

	### Example
	```lua
	local dirPath = DirectoryPath.new("path/to/dir"):withDirWritten()
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@param allowOverwrite boolean? -- Whether to allow overwriting an existing directory. Defaults to `false`.
	@return DirectoryPath -- The `DirectoryPath` instance
]=]
function DirectoryPath.withDirWritten(self, allowOverwrite)
	assert(optionalBooleanType(allowOverwrite))

	if self:isDir() then
		if allowOverwrite then
			self:removeDir()
		else
			error(`Not allowed to overwrite a directory. A directory already exists at that path({self.path})`)
		end
	end
	if fs.isFile(self.path) then
		error(`Cannot write a directory. The file already exists at that path({self.path})`)
	end
	self:writeDir()

	return self
end

--[=[
	@within DirectoryPath

	Checks if a value is a `DirectoryPath` instance.

	@param value any -- The value to check
	@return boolean -- Whether the value is a `DirectoryPath` instance
]=]
function DirectoryPath.is(value)
	return type(value) == "table" and getmetatable(value) == DirectoryPath
end

--[=[
	@within DirectoryPath
	@tag must_use

	Checks if the directory exists.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read at the directory path.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
	@return boolean -- Whether the directory exists
]=]
function DirectoryPath.isDir(self)
	return fs.isDir(self.path)
end

--[=[
	@within DirectoryPath
	@tag must_use

	Reads the contents of the directory.

	An error will be thrown in the following situations:

	* The directory does not exist.
	* The current process lacks permissions to read at the directory path.
	* Some other I/O error occurred.

	### Example
	```lua
	local dirPath = DirectoryPath.fromExisting("path/to/dir")
	for _, name in dirPath:readDir() do
		print(name)
	end
	```

	@param self DirectoryPath -- The DirectoryPath instance
	@return { string } -- A table containing the entries in the directory
]=]
function DirectoryPath.readDir(self)
	return fs.readDir(self.path)
end

--[=[
	@within DirectoryPath

	Writes the directory to the filesystem.

	An error will be thrown in the following situations:

	* A file already exists at the directory path.
	* The current process lacks permissions to write the directory.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
]=]
function DirectoryPath.writeDir(self)
	return fs.writeDir(self.path)
end

--[=[
	@within DirectoryPath

	Removes the directory from the filesystem.

	An error will be thrown in the following situations:

	* The directory does not exist.
	* The current process lacks permissions to remove the directory.
	* Some other I/O error occurred.

	@param self DirectoryPath -- The DirectoryPath instance
]=]
function DirectoryPath.removeDir(self)
	return fs.removeDir(self.path)
end

return DirectoryPath
end function __DARKLUA_BUNDLE_MODULES.aI():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aI if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aI=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aH()
local types = __DARKLUA_BUNDLE_MODULES.aE()

local PathType = types.PathType
local AsPathType = types.AsPathType
local ContentsType = types.ContentsType
local optionalBooleanType = types.optionalBooleanType
local stringType = types.stringType
local booleanType = types.booleanType

--[=[
	@class FilePath

	Represents a file path.

	### Example
	```lua
	local filePath = FilePath.fromExisting("path/to/file")
	filePath:writeFile("content")
	```
]=]
























local FilePath = {} :: FilePathImpl__DARKLUA_TYPE_br
FilePath.__index = FilePath
--[=[
	@within FilePath
	@prop path Path
	The underlying `Path` instance.
]=]

--[=[
	@within FilePath

	Returns a string representation of the `FilePath` instance.

	### Example
	```lua
	local filePath = FilePath.fromExisting("path/to/file")
	print(filePath) -- Output: FilePath<path/to/file>
	```

	@param self FilePath -- The FilePath instance
	@return string -- A string representation of the FilePath instance
]=]
function FilePath.__tostring(self)
	assert(PathType(self.path))

	return `FilePath<{self.path}>`
end

--[=[
	@within FilePath

	Creates a new `FilePath` instance.

	@param filePath AsPath -- The file path
	@return FilePath -- A new `FilePath` instance
]=]
function FilePath.new(filePath)
	assert(AsPathType(filePath))

	return setmetatable({
		path = Path.from(filePath),
	}, FilePath)
end

--[=[
	@within FilePath

	Creates a new `FilePath` instance from an existing file path.

	An error will be thrown if there is no file at the given path.

	@param filePath AsPath -- The existing file path
	@return FilePath -- A new `FilePath` instance
]=]
function FilePath.fromExisting(filePath)
	assert(AsPathType(filePath))

	if not fs.isFile(filePath) then
		error(`There is no file at that path({filePath})`)
	end

	return setmetatable({
		path = Path.from(filePath),
	}, FilePath)
end

--[=[
	@within FilePath

	Writes the file to the filesystem.

	An error will be thrown in the following situations:

	* The current process lacks permissions to write the file.
	* Some other I/O error occurred.

	### Example
	```lua
	local filePath = FilePath.new("path/to/file"):withFileWritten("content")
	```

	@param self FilePath -- The FilePath instance
	@param contents Contents -- The contents to write to the file
	@param allowOverwrite boolean? -- Whether to allow overwriting an existing file. Defaults to `false`.
	@return FilePath -- The `FilePath` instance
]=]
function FilePath.withFileWritten(self, contents, allowOverwrite)
	assert(ContentsType(contents))
	assert(optionalBooleanType(allowOverwrite))

	if self:isFile() then
		if allowOverwrite then
			self:removeFile()
		else
			error(`Not allowed to overwrite a file. A file already exists at that path({self.path})`)
		end
	end
	if fs.isDir(self.path) then
		error(`Cannot create a new file. The directory already exists at that path({self.path})`)
	end
	self:writeFile(contents)

	return self
end

--[=[
	@within FilePath

	Checks if a value is a `FilePath` instance.

	@param value any -- The value to check
	@return boolean -- Whether the value is a `FilePath` instance
]=]
function FilePath.is(value)
	return type(value) == "table" and getmetatable(value) == FilePath
end

--[=[
	@within FilePath
	@tag must_use

	Checks if the file exists at the path.

	@param self FilePath -- The FilePath instance
	@return boolean -- Whether the file exists at the path
]=]
function FilePath.isFile(self)
	return fs.isFile(self.path)
end

--[=[
	@within FilePath
	@tag must_use

	Reads the file contents.

	An error will be thrown in the following situations:

	* The current process lacks permissions to read the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
	@return string -- The file contents
]=]
function FilePath.readFile(self)
	return fs.readFile(self.path)
end

--[=[
	@within FilePath

	Writes contents to the file.

	An error will be thrown in the following situations:

	* The current process lacks permissions to write the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
	@param contents Contents -- The contents to write to the file
]=]
function FilePath.writeFile(self, contents)
	return fs.writeFile(self.path, contents)
end

--[=[
	@within FilePath

	Removes the file.

	An error will be thrown in the following situations:

	* The file does not exist.
	* The current process lacks permissions to remove the file.
	* Some other I/O error occurred.

	@param self FilePath -- The FilePath instance
]=]
function FilePath.removeFile(self)
	return fs.removeFile(self.path)
end

return FilePath
end function __DARKLUA_BUNDLE_MODULES.aJ():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aJ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aJ=v end return v.c end end do local function __modImpl()
local process = require("@lune/process")
local pathSeparator = process.os == "windows" and "\\" or "/"
-- selene: allow(global_usage)
_G.SYS_PATH_SEPARATOR = pathSeparator
local luauPath = __DARKLUA_BUNDLE_MODULES.aA()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aH()
local gt = __DARKLUA_BUNDLE_MODULES.aD()
local types = __DARKLUA_BUNDLE_MODULES.aE()
local vfs = __DARKLUA_BUNDLE_MODULES.aG()
local createPath = vfs.createPath
local normalizePath = __DARKLUA_BUNDLE_MODULES.aF()
local cwd = vfs.cwd
local DirectoryPath = __DARKLUA_BUNDLE_MODULES.aI()
local luneFileSystem = require("@lune/fs")
local FilePath = __DARKLUA_BUNDLE_MODULES.aJ()
local task = require("@lune/task")
local serde = require("@lune/serde")











local PathType = types.PathType
local AsPathType = types.AsPathType
local optionalBooleanType = types.optionalBooleanType
local ContentsType = types.ContentsType

--[=[
	@class pathfs

	luau-path + @lune/fs with some utilities
]=]
local pathfs = {}
--[=[
	@prop fs fs
	@within pathfs
]=]
pathfs.fs = fs
--[=[
	@prop DirectoryPath DirectoryPath
	@within pathfs
]=]
pathfs.DirectoryPath = DirectoryPath
--[=[
	@prop FilePath FilePath
	@within pathfs
]=]
pathfs.FilePath = FilePath
--[=[
	@prop pathSeparator string
	@within pathfs

	Current path separator

	### Example
	```lua
	if process.os == "windows" then
		print(pathfs.pathSeparator) -- "\\" (Windows)
	else
		print(pathfs.pathSeparator) -- "/" (other OS, maybe Linux)
	end
	```
]=]
pathfs.pathSeparator = pathSeparator
--[=[
	@external Component https://github.com/seaofvoices/luau-path/blob/main/src/Component.luau
	@prop Component Component
	@within pathfs

	A `Component` class exported from `luau-path`
]=]
pathfs.Component = getmetatable(Path.from("a"):components():collect()[1] :: any).__index :: Component__DARKLUA_TYPE_bB & {
	normal: (value: string) -> Component__DARKLUA_TYPE_bB,
	rootDir: () -> Component__DARKLUA_TYPE_bB,
	curDir: () -> Component__DARKLUA_TYPE_bB,
	parentDir: () -> Component__DARKLUA_TYPE_bB,
	prefix: (raw: string, prefix: any) -> Component__DARKLUA_TYPE_bB,
}
pathfs.normalize = normalizePath
pathfs.cwd = cwd
--[=[
	@prop Path Path
	@within pathfs

	A `Path` class exported from `luau-path`

	### Example
	```lua
	local path = Path.from("path/to/file")
	```
]=]
pathfs.Path = Path

local function extendTable<K, V>(target: { V }, tbl: { [K]: V })
	for _, v in tbl do
		table.insert(target, v)
	end
end

local optionalNumberType = gt.build(gt.opt(gt.number()))
--[=[
	@within pathfs

	Gets current script context's path. (default level is `2`)

	An error will be thrown in the following situations:

	* script path found in `debug.info(level)` is not resolvable.
]=]
function pathfs.script(level: typeof(optionalNumberType:type())): typeof(PathType:type())
	assert(optionalNumberType(level))

	local path = string.match(debug.info(level or 2, "s"), '%[string "([^"]*)"%]')
	if path then
		local luauOne = path .. ".luau"
		local luaOne = path .. ".lua"

		if fs.isFile(luauOne) then
			return Path.from(luauOne)
		elseif fs.isFile(luaOne) then
			return Path.from(luaOne)
		elseif fs.isFile(path) then
			return Path.from(path)
		end
	end

	error("Failed to get script path")
end

--[=[
	@within pathfs

	Gets absolute path of given path just by joining the `pathfs.cwd` and the path.
]=]
function pathfs.absolute(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)

	if path:isAbsolute() then
		return path
	end

	return normalizePath(cwd():join(path))
end

--[=[
	@within pathfs

	Gets a path without the current directory component.
]=]
function pathfs.withoutCurDir(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local components = path:components()
	local firstComponent = components:next()
	if firstComponent and firstComponent.type == "curDir" then
		return createPath(components)
	end

	return path
end

local optionalPathType = gt.build(gt.opt(PathType:type()))
local optionalStringType = gt.build(gt.opt(gt.string()))
--[=[
	@within pathfs

	Construct a relative path from a provided base directory path to the provided path.

	Implementation inspired by https://github.com/Manishearth/pathdiff
]=]
function pathfs.diff(
	target: typeof(AsPathType:type()),
	base: typeof(AsPathType:type()),
	separator: typeof(optionalStringType:type())
): typeof(optionalPathType:type())
	assert(AsPathType(target))
	assert(AsPathType(base))
	assert(optionalStringType(separator))

	separator = separator or pathfs.pathSeparator
	-- selene: allow(shadowing)
	local target = createPath(target)
	-- selene: allow(shadowing)
	local base = createPath(base)

	if target:isAbsolute() ~= base:isAbsolute() then
		if target:isAbsolute() then
			return target
		else
			return
		end
	else
		local ita = target:components()
		local itb = base:components()
		local comps = {}
		while true do
			local a, b = ita:next(), itb:next()
			if not a and not b then
				break
			elseif a and not b then
				table.insert(comps, a)
				extendTable(comps, ita:collect())
			elseif not a then
				table.insert(comps, pathfs.Component.parentDir())
			elseif a and b and #comps == 0 and a == b then
				continue
			elseif a and b and b.type == "curDir" then
				table.insert(comps, a)
			elseif a and b and b.type == "parentDir" then
				return
			elseif a and b then
				table.insert(comps, pathfs.Component.parentDir())
				for _, _ in itb do
					table.insert(comps, pathfs.Component.parentDir())
				end
				table.insert(comps, a)
				extendTable(comps, ita:collect())
				break
			end
		end
		local strComps = {}
		for _, comp in comps do
			table.insert(strComps, comp:toString())
		end
		return Path.from(table.concat(strComps, separator))
	end
end

--[=[
	@within pathfs

	Returns the canonical, absolute form of a path with all intermediate components normalized and symbolic links resolved.
]=]
function pathfs.canonicalize(path: typeof(AsPathType:type())): typeof(PathType:type())
	assert(AsPathType(path))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local absolutePath = pathfs.absolute(path)
	if fs.isFile(absolutePath) or fs.isDir(absolutePath) then
		return absolutePath
	end

	error(`Failed to canonicalize the path('{path}'). does not exist`)
end

--[=[
	@within pathfs

	Creates a new `Path` based on the current dir path.

	An error will be thrown in the following situations:

	* Errors while calling `pathfs.script(3)`.
	* Current script path's parent path does not exist.
]=]
function pathfs.fromDir(
	path: typeof(AsPathType:type()),
	relative: typeof(optionalBooleanType:type())
): typeof(PathType:type())
	assert(AsPathType(path))
	assert(optionalBooleanType(relative))

	-- selene: allow(shadowing)
	local path = createPath(path)
	local currentScriptPath = pathfs.script(3)
	local resolved = if relative == true then currentScriptPath else pathfs.canonicalize(currentScriptPath)
	local parent = resolved:parent()
	if parent then
		return parent:join(path)
	end
	error("Failed to perform 'fromDir'. parent does not exist in the script path")
end

--[=[
	@within pathfs

	Get the dir path based on the current script context.

	An error will be thrown in the following situations:

	* Errors while calling `pathfs.getScriptPath()`.
	* Current script path's parent path does not exist.
]=]
function pathfs.getDir(relative: typeof(optionalBooleanType:type())): typeof(PathType:type())
	assert(optionalBooleanType(relative))

	local currentScriptPath = pathfs.script(3)
	local resolved = if relative == true then currentScriptPath else pathfs.canonicalize(currentScriptPath)
	local parent = resolved:parent()
	if parent then
		return parent
	end
	error("Failed to get dir path. parent does not exist in the script path")
end

--[=[
	@within pathfs

	Finds a file at the given file path.
	@param filePath -- The path to the file, of type AsPathType.
	@return FilePath? -- A File object if the file exists, otherwise nil.
]=]
function pathfs.findFile(filePath: typeof(AsPathType:type())): FilePath__DARKLUA_TYPE_bt?
	assert(AsPathType(filePath))

	-- selene: allow(shadowing)
	local dirPath = createPath(filePath)
	if fs.isFile(dirPath) then
		return FilePath.fromExisting(dirPath)
	end

	return
end

--[=[
	@within pathfs

	Finds a directory at the given directory path.
	@param dirPath -- The path to the directory, of type AsPathType.
	@return DirectoryPath? -- A Directory object if the directory exists, otherwise nil.
]=]
function pathfs.findDir(dirPath: typeof(AsPathType:type())): DirectoryPath__DARKLUA_TYPE_bs?
	assert(AsPathType(dirPath))

	-- selene: allow(shadowing)
	local dirPath = createPath(dirPath)
	if fs.isDir(dirPath) then
		return DirectoryPath.fromExisting(dirPath)
	end

	return
end

local directoryType = gt.build(gt.union(
	gt.custom(DirectoryPath.is, "DirectoryPath"),
	AsPathType:type()
))


















local function hashDirEntry(entry: DirEntry__DARKLUA_TYPE_bC): string
	return entry.path:toString()
end

local function directoryToPath(dir: typeof(directoryType:type())): typeof(PathType:type())
	local path: typeof(PathType:type()) = if DirectoryPath.is(dir)
		then (dir :: DirectoryPath__DARKLUA_TYPE_bs).path
		else createPath(dir :: typeof(AsPathType:type()))

	if not fs.isDir(path) then
		error(`The provided path \`{path}\` is not a valid directory`)
	end

	return path
end

--[=[
	@within pathfs

	Get the entries of a directory.

	### Example
	```lua
	for _, entry in pathfs.getEntries("path/to/dir") do
		print(entry.name) -- File name of this directory entry without any leading path component(s)
		print(entry.file) -- File object if it exists
		print(entry.directory) -- Directory object if it exists
	end
	```

	@param directory -- The directory to get entries from, of type Directory or AsPathType.
	@return { DirEntry } -- A table containing the entries in the directory.
]=]
function pathfs.getEntries(directory: typeof(directoryType:type())): { DirEntry__DARKLUA_TYPE_bC }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry__DARKLUA_TYPE_bC } = {}

	for _, entryName in fs.readDir(directory) do
		local path = directory:join(entryName)
		table.insert(entries, {
			name = entryName,
			file = pathfs.findFile(path),
			dir = pathfs.findDir(path),
			path = path,
		})
	end

	return entries
end

--[=[
	@within pathfs

	Get the entries of a directory.

	### Example
	```lua
	for _, entry in pathfs.getDescendantEntries("path/to/dir") do
		print(entry.name) -- File name of this directory entry without any leading path component(s)
		print(entry.file) -- File object if it exists
		print(entry.directory) -- Directory object if it exists
	end
	```

	@param directory -- The directory to get entries from, of type Directory or AsPathType.
	@return { DirEntry } -- A table containing the entries in the directory.
]=]
function pathfs.getDescendantEntries(directory: typeof(directoryType:type())): { DirEntry__DARKLUA_TYPE_bC }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry__DARKLUA_TYPE_bC } = {}

	for _, entryName in fs.readDir(directory) do
		local path = directory:join(entryName)

		table.insert(entries, {
			name = entryName,
			file = pathfs.findFile(path),
			directory = pathfs.findDir(path),
			path = path,
		})

		if fs.isDir(path) then
			local deepEntries = pathfs.getDescendantEntries(path)

			for _, deepEntry: DirEntry__DARKLUA_TYPE_bC in deepEntries do
				table.insert(entries, deepEntry)
			end
		end
	end

	return entries
end

-- original source credits to: https://github.com/ffrostfall/lunePackages/blob/e6335a8c44957afbf1b00e3ecca37ac6a03af14d/watch/init.luau
local function watchPaths(paths: { string }, callback: () -> ())
	local lastModified = {}

	for _, path in paths do
		lastModified[path] = fs.metadata(path).modifiedAt
	end

	while true do
		local changed = false

		for path, modified in lastModified do
			local newModified = fs.metadata(path).modifiedAt
			if newModified ~= modified then
				lastModified[path] = newModified
				changed = true
				break
			end
		end

		if changed then
			task.spawn(callback)
		end

		task.wait(1)
	end
end

local directoriesArrayType = gt.build(gt.array(directoryType:type()))
local callbackType = gt.build(gt.anyfn())
--[=[
	@within pathfs

	Watch directories for changes.

	### Example
	```lua
	pathfs.watchDirectories({"path/to/dir1", "path/to/dir2"}, function()
		print("Changed!")
	end)
	```
]=]
function pathfs.watchDirectories(
	directories: typeof(directoriesArrayType:type()),
	onChanged: typeof(callbackType:type())
): thread
	assert(directoriesArrayType(directories))
	assert(callbackType(onChanged))

	local paths = {}

	for _, dir in directories do
		-- selene: allow(shadowing)
		local dir = directoryToPath(dir)
		for _, filePath in pathfs.getDescendantEntries(dir) do
			table.insert(paths, filePath.path:toString())
		end
	end

	task.spawn(onChanged)
	return task.spawn(watchPaths, paths, onChanged)
end

--[=[
	@within pathfs

	Watch a file for changes.

	### Example
	```lua
	pathfs.watchFile("path/to/file", function()
		print("Changed!")
	end)
	```
]=]
function pathfs.watchFile(fileName: typeof(AsPathType:type()), onChanged: typeof(callbackType:type())): thread
	assert(AsPathType(fileName))
	assert(callbackType(onChanged))

	task.spawn(onChanged)
	return task.spawn(function()
		local lastModified = fs.metadata(fileName).modifiedAt

		while true do
			local newModified = fs.metadata(fileName).modifiedAt
			if newModified ~= lastModified then
				task.spawn(onChanged)

				lastModified = newModified
			end

			task.wait(1)
		end
	end)
end

local function watchEntryAdded(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_bC },
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onAdded))

	local oldEntries: { [string]: DirEntry__DARKLUA_TYPE_bC } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry__DARKLUA_TYPE_bC } = {}
			do
				local ok, entries = pcall(getEntries, directory)
				if not ok then -- This may no longer be a valid directory
					return
				end
				for _, entry in entries do
					newEntries[hashDirEntry(entry)] = entry
				end
			end
			for _, newEntry in newEntries do
				if not oldEntries[hashDirEntry(newEntry)] then
					task.spawn(onAdded, newEntry)
				end
			end

			oldEntries = newEntries

			task.wait(1)
		end
	end)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for added entries.

	### Example
	```lua
	pathfs.watchEntryAdded("path/to/dir", function(addedEntry)
		print("Added entry:", addedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onAdded -- The callback function to call when an entry is added.
]=]
function pathfs.watchEntryAdded(
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchEntryAdded is deprecated and will be removed in future releases")

	return watchEntryAdded(pathfs.getEntries, directory, onAdded)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for added descendant entries.

	### Example
	```lua
	pathfs.watchDescendantEntryAdded("path/to/dir", function(addedEntry)
		print("Added entry:", addedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onAdded -- The callback function to call when an entry is added.
]=]
function pathfs.watchDescendantEntryAdded(
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryAdded is deprecated and will be removed in future releases")

	return watchEntryAdded(pathfs.getDescendantEntries, directory, onAdded)
end

local function watchEntryRemoved(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_bC },
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onRemoved))

	local oldEntries: { [string]: DirEntry__DARKLUA_TYPE_bC } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry__DARKLUA_TYPE_bC } = {}
			do
				local ok, entries = pcall(getEntries, directory)
				if not ok then -- This may no longer be a valid directory
					return
				end
				for _, entry in entries do
					newEntries[hashDirEntry(entry)] = entry
				end
			end
			for _, oldEntry in oldEntries do
				if not newEntries[hashDirEntry(oldEntry)] then
					task.spawn(onRemoved, oldEntry)
				end
			end

			oldEntries = newEntries

			task.wait(1)
		end
	end)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for removed entries.

	### Example
	```lua
	pathfs.watchEntryRemoved("path/to/dir", function(removedEntry)
		print("Removed entry:", removedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onRemoved -- The callback function to call when an entry is removed.
]=]
function pathfs.watchEntryRemoved(
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchEntryRemoved is deprecated and will be removed in future releases")

	return watchEntryRemoved(pathfs.getEntries, directory, onRemoved)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Watch a directory for removed descendant entries.

	### Example
	```lua
	pathfs.watchDescendantEntryRemoved("path/to/dir", function(removedEntry)
		print("Removed entry:", removedEntry.name)
	end)
	```

	@param directory -- The directory to watch, of type Directory or AsPathType.
	@param onRemoved -- The callback function to call when an entry is removed.
]=]
function pathfs.watchDescendantEntryRemoved(
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_bC) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryRemoved is deprecated and will be removed in future releases")

	return watchEntryRemoved(pathfs.getDescendantEntries, directory, onRemoved)
end

local FileOrAsPathType = gt.build(gt.union(
	gt.custom(FilePath.is, "FilePath"),
	AsPathType:type()
))

local function fileOrAsPathToPath(fileOrPath: typeof(FileOrAsPathType:type())): Path__DARKLUA_TYPE_bz
	return createPath(if FilePath.is(fileOrPath) then (fileOrPath :: FilePath__DARKLUA_TYPE_bt).path else fileOrPath :: AsPath__DARKLUA_TYPE_bA)
end

--[=[
	@within pathfs

	Write a file, creating parent directories if they do not exist.

	### Example
	```lua
	pathfs.writeFileAll("path/to/file", "content")
	```

	@param fileOrPath -- The file or path to write to, of type FilePath or AsPathType.
	@param contents -- The contents to write to the file, of type string or table.
]=]
function pathfs.writeFileAll(fileOrPath: typeof(FileOrAsPathType:type()), contents: typeof(ContentsType:type()))
	assert(FileOrAsPathType(fileOrPath))
	assert(ContentsType(contents))

	-- selene: allow(shadowing)
	local path = fileOrAsPathToPath(fileOrPath)
	local parent = path:parent()
	if parent then
		fs.writeDir(parent)
	end
	fs.writeFile(path, contents)
end







local function observeEntry(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_bC },
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_bC) -> (() -> ())?)
): () -> ()
	assert(directoryType(directory))
	assert(callbackType(callback))

	local entryValues: {
		[string]: EntryValue__DARKLUA_TYPE_bE?,
	} = {}
	local disconnected = false
	local function attemptStartup(entryValue: EntryValue__DARKLUA_TYPE_bE)
		entryValue.stateOrCleanup = "__inflight__"

		task.defer(function()
			if entryValue.stateOrCleanup ~= "__inflight__" then
				return
			end

			local success, errOrCleanup = pcall(function()
				local cleanup = callback(entryValue.entry)
				if cleanup ~= nil and type(cleanup) ~= "function" then
					error("observeDescendantEntry's callback must return a cleanup function or nil")
				end
				return cleanup
			end)

			if not success then
				print(`Error in observeDescendantEntry callback:\n\t{errOrCleanup}`)
				return
			end

			if entryValue.stateOrCleanup == "__inflight__" then
				entryValue.stateOrCleanup = errOrCleanup
			elseif type(errOrCleanup) == "function" then
				task.spawn(errOrCleanup)
			end
		end)
	end

	local function attemptCleanup(entryValue: EntryValue__DARKLUA_TYPE_bE)
		local cleanup = entryValue.stateOrCleanup
		entryValue.stateOrCleanup = "__dead__"
		if type(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	local function onAdded(entry: DirEntry__DARKLUA_TYPE_bC)
		if disconnected then
			return
		end
		local hash = hashDirEntry(entry)
		if entryValues[hash] then
			return
		end

		local entryValue = {
			stateOrCleanup = "__dead__" :: "__dead__",
			entry = entry,
		}
		entryValues[hash] = entryValue

		attemptStartup(entryValue)
	end

	local function onRemoved(entry: DirEntry__DARKLUA_TYPE_bC)
		local hash = hashDirEntry(entry)
		local entryValue = entryValues[hash]
		if not entryValue then
			return
		end

		attemptCleanup(entryValue)
		entryValues[hash] = nil
	end

	local addedWatchingThread = watchEntryAdded(getEntries, directory, onAdded)
	local removedWatchingThread = watchEntryRemoved(getEntries, directory, onRemoved)

	task.defer(function()
		if disconnected then
			return
		end
		for _, entry in getEntries(directory) do
			task.spawn(onAdded, entry)
		end
	end)

	return function()
		disconnected = true
		task.cancel(addedWatchingThread)
		task.cancel(removedWatchingThread)
		local value
		do
			local _, newValue = next(entryValues)
			value = newValue
		end
		while value do
			onRemoved(value.entry)
			local _, newValue = next(entryValues)
			value = newValue
		end
	end
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Observe a directory for changes.

	### Example
	```lua
	pathfs.observeEntry("path/to/dir", function(entry)
		print("Entry changed:", entry.name)

		return function()
			print("Entry cleanup:", entry.name)
		end
	end)
	```

	@param directory -- The directory to observe, of type Directory or AsPathType.
	@param callback -- The callback function to call when an entry is added or removed.
]=]
function pathfs.observeEntry(
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_bC) -> (() -> ())?)
): () -> ()
	-- selene: allow(undefined_variable)
	warn("pathfs.observeEntry is deprecated and will be removed in future releases")

	return observeEntry(pathfs.getEntries, directory, callback)
end

--[=[
	@within pathfs
	@deprecated v0.6.0

	Observe a directory for changes in its descendants.

	### Example
	```lua
	pathfs.observeDescendantEntry("path/to/dir", function(entry)
		print("Descendant entry changed:", entry.name)

		return function()
			print("Cleanup for entry:", entry.name)
		end
	end)
	```

	@param directory -- The directory to observe, of type Directory or AsPathType.
	@param callback -- The callback function to call when an entry is added or removed.
]=]
function pathfs.observeDescendantEntry(
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_bC) -> (() -> ())?)
): () -> ()
	-- selene: allow(undefined_variable)
	warn("pathfs.observeDescendantEntry is deprecated and will be removed in future releases")

	return observeEntry(pathfs.getDescendantEntries, directory, callback)
end

--[=[
	@within pathfs

	Serializes a value to a file based on the file extension.
	Supports JSON (.json), TOML (.toml), and YAML (.yaml, .yml) formats.

	### Example
	```lua
	local data = { name = "example", value = 42 }
	pathfs.serializeFile(data, "config.json")
	pathfs.serializeFile(data, "config.toml")
	pathfs.serializeFile(data, "config.yaml")
	```

	@param value -- The value to serialize
	@param fileOrPath -- The file path or FilePath object
]=]
function pathfs.serializeFile(value: any, fileOrPath: typeof(FileOrAsPathType:type()))
	assert(FileOrAsPathType(fileOrPath))

	local path = fileOrAsPathToPath(fileOrPath)
	local extension = string.lower(path:extension() or "")

	local content: string
	if extension == "json" then
		content = serde.encode("json", value)
	elseif extension == "toml" then
		content = serde.encode("toml", value)
	elseif extension == "yaml" or extension == "yml" then
		content = serde.encode("yaml", value)
	else
		error(`Unsupported file format: {extension}. Supported formats are: json, toml, yaml, yml`)
	end

	fs.writeFile(path, content)
end

--[=[
	@within pathfs

	Deserializes a file based on the file extension.
	Supports JSON (.json), TOML (.toml), and YAML (.yaml, .yml) formats.

	### Example
	```lua
	local config = pathfs.deserializeFile("config.json")
	local settings = pathfs.deserializeFile("settings.toml")
	local data = pathfs.deserializeFile("data.yaml")
	```

	@param fileOrPath -- The file path or FilePath object
	@return any -- The deserialized value
]=]
function pathfs.deserializeFile(fileOrPath: typeof(FileOrAsPathType:type())): any
	assert(FileOrAsPathType(fileOrPath))

	local path = fileOrAsPathToPath(fileOrPath)

	if not fs.isFile(path) then
		error(`File does not exist: {path}`)
	end

	local content = fs.readFile(path)
	local extension = string.lower(path:extension() or "")

	if extension == "json" then
		return serde.decode("json", content)
	elseif extension == "toml" then
		return serde.decode("toml", content)
	elseif extension == "yaml" or extension == "yml" then
		return serde.decode("yaml", content)
	else
		error(`Unsupported file format: {extension}. Supported formats are: json, toml, yaml, yml`)
	end
end

return pathfs
end function __DARKLUA_BUNDLE_MODULES.aK():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aK if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aK=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aK()











return module end function __DARKLUA_BUNDLE_MODULES.aL():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aL if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aL=v end return v.c end end end
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local pathfs = __DARKLUA_BUNDLE_MODULES.aL()

local function findSourcemapInTree(): string?
	local currentPath = pathfs.Path.from(process.cwd)

	-- Walk up the directory tree looking for sourcemap.json
	while true do
		local sourcemapPath = currentPath:join("sourcemap.json"):toString()

		if fs.isFile(sourcemapPath) then
			return sourcemapPath
		end

		-- Get parent directory
		local parentPath = currentPath:parent()

		-- Stop if we've reached the root
		if parentPath == nil or parentPath:toString() == currentPath:toString() then
			break
		end

		currentPath = parentPath
	end

	return nil
end

local function loadSourcemap(path: string)
	if not fs.isFile(path) then
		return nil, `Sourcemap file not found: {path}`
	end

	local content = fs.readFile(path)
	local success, result = pcall(serde.decode, "json", content)

	if not success then
		return nil, `Failed to parse sourcemap: {result}`
	end

	return result, nil
end

local function findInstancePath(sourcemap: any, filePath: string): string?
	local normalizedPath = filePath:gsub("\\", "/")

	local function searchNode(node: any, currentPath: string): string?
		if node.filePaths then
			for _, file in node.filePaths do
				if file == normalizedPath or file:find(normalizedPath, 1, true) then
					return currentPath
				end
			end
		end

		if node.children then
			for _, child in node.children do
				local childPath = if currentPath == "game" then `game["{child.name}"]` else `{currentPath}["{child.name}"]`

				local found = searchNode(child, childPath)
				if found then
					return found
				end
			end
		end

		return nil
	end

	return searchNode(sourcemap, "game")
end

return {
	findSourcemapInTree = findSourcemapInTree,
	loadSourcemap = loadSourcemap,
	findInstancePath = findInstancePath,
}
