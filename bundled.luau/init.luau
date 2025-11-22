
type ArgsPras__DARKLUA_TYPE_a = {}
type InMutex__DARKLUA_TYPE_b = number & { __brand: "InMutex" }

type args__DARKLUA_TYPE_c = number | string | "A-B" | "N+" | "?" | "*" | "+"

type convert2__DARKLUA_TYPE_d = (() -> () )| { () -> () } | { [string]: any } | typeof(tonumber) | typeof(stdio.ewrite)

type convert__DARKLUA_TYPE_e = convert2__DARKLUA_TYPE_d | { [(number | string)]: convert2__DARKLUA_TYPE_d }

type count__DARKLUA_TYPE_f = number | string | "A-B" | "N+" | "?" | "*" | "+"

type Name__DARKLUA_TYPE_g<T> = (self: T, name: string) -> T

type Description__DARKLUA_TYPE_h<T> = (self: T, description: string) -> T

type Default__DARKLUA_TYPE_i<T> = (self: T, default: any) -> T

type Convert__DARKLUA_TYPE_j<T> = (self: T, convert: convert__DARKLUA_TYPE_e) -> T

type Args__DARKLUA_TYPE_k<T> = (self: T, args: args__DARKLUA_TYPE_c) -> T

type Count__DARKLUA_TYPE_l<T> = (self: T, count: count__DARKLUA_TYPE_f) -> T

type Epilog__DARKLUA_TYPE_m<T> = (self: T, epilog: string) -> T

type Target__DARKLUA_TYPE_n<T> = (self: T, target: string) -> T

type Require_command__DARKLUA_TYPE_o<T> = (self: T, boolean) -> T

type Defmode__DARKLUA_TYPE_p<T> = (self: T, defmode: string) -> T

type Init__DARKLUA_TYPE_q<T> = (self: T, Init: { [(number | string)]: string }) -> T

type Action__DARKLUA_TYPE_r<T> = (
	self: T,
	Action: ((args: any?, _: any?, exceptions: any?) -> ()
)		| "store"
		| "store_true"
		| "store_false"
		| "count"
		| "append"
		| "concat"
) -> T

type Hidden__DARKLUA_TYPE_s<T> = (self: T, Hidden: boolean) -> T

type Argname__DARKLUA_TYPE_t<T> = (self: T, argname: string | { [number]: string }) -> T

type argument__DARKLUA_TYPE_u = {
	name: Name__DARKLUA_TYPE_g<argument__DARKLUA_TYPE_u>,
	description: Description__DARKLUA_TYPE_h<argument__DARKLUA_TYPE_u>,
	default: Default__DARKLUA_TYPE_i<argument__DARKLUA_TYPE_u>,
	convert: Convert__DARKLUA_TYPE_j<argument__DARKLUA_TYPE_u>,
	args: Args__DARKLUA_TYPE_k<argument__DARKLUA_TYPE_u>,
	target: Target__DARKLUA_TYPE_n<argument__DARKLUA_TYPE_u>,
	init: Init__DARKLUA_TYPE_q<argument__DARKLUA_TYPE_u>,
	action: Action__DARKLUA_TYPE_r<argument__DARKLUA_TYPE_u>,
	hidden: Hidden__DARKLUA_TYPE_s<argument__DARKLUA_TYPE_u>,
	argname: Argname__DARKLUA_TYPE_t<argument__DARKLUA_TYPE_u>,
} & InMutex__DARKLUA_TYPE_b

type option__DARKLUA_TYPE_v = {
	name: Name__DARKLUA_TYPE_g<option__DARKLUA_TYPE_v>,
	description: Description__DARKLUA_TYPE_h<option__DARKLUA_TYPE_v>,
	default: Default__DARKLUA_TYPE_i<option__DARKLUA_TYPE_v>,
	convert: Convert__DARKLUA_TYPE_j<option__DARKLUA_TYPE_v>,
	args: Args__DARKLUA_TYPE_k<option__DARKLUA_TYPE_v>,
	count: Count__DARKLUA_TYPE_l<option__DARKLUA_TYPE_v>,
	target: Target__DARKLUA_TYPE_n<option__DARKLUA_TYPE_v>,
	defmode: Defmode__DARKLUA_TYPE_p<option__DARKLUA_TYPE_v>,
	init: Init__DARKLUA_TYPE_q<option__DARKLUA_TYPE_v>,
	action: Action__DARKLUA_TYPE_r<option__DARKLUA_TYPE_v>,
	hidden: Hidden__DARKLUA_TYPE_s<option__DARKLUA_TYPE_v>,
	argname: Argname__DARKLUA_TYPE_t<option__DARKLUA_TYPE_v>,
} & InMutex__DARKLUA_TYPE_b

type flag__DARKLUA_TYPE_w = {
	name: Name__DARKLUA_TYPE_g<flag__DARKLUA_TYPE_w>,
	description: Description__DARKLUA_TYPE_h<flag__DARKLUA_TYPE_w>,
	default: Default__DARKLUA_TYPE_i<flag__DARKLUA_TYPE_w>,
	convert: Convert__DARKLUA_TYPE_j<flag__DARKLUA_TYPE_w>,
	args: Args__DARKLUA_TYPE_k<flag__DARKLUA_TYPE_w>,
	count: Count__DARKLUA_TYPE_l<flag__DARKLUA_TYPE_w>,
	target: Target__DARKLUA_TYPE_n<flag__DARKLUA_TYPE_w>,
	init: Init__DARKLUA_TYPE_q<flag__DARKLUA_TYPE_w>,
	action: Action__DARKLUA_TYPE_r<flag__DARKLUA_TYPE_w>,
	hidden: Hidden__DARKLUA_TYPE_s<flag__DARKLUA_TYPE_w>,
	argname: Argname__DARKLUA_TYPE_t<flag__DARKLUA_TYPE_w>,
} & InMutex__DARKLUA_TYPE_b

type mutex__DARKLUA_TYPE_x = {}

type command__DARKLUA_TYPE_y = Parser__DARKLUA_TYPE_B & InMutex__DARKLUA_TYPE_b

type command_target__DARKLUA_TYPE_z = Parser__DARKLUA_TYPE_B & InMutex__DARKLUA_TYPE_b

type __callPlusType__DARKLUA_TYPE_A = typeof(setmetatable(
	{} :: Parser__DARKLUA_TYPE_B,
	{} :: {
		__call: (self: any, {
			name: string?,
			description: string?,
			epilog: string?,
		}) -> Parser__DARKLUA_TYPE_B,
	}
))

type Parser__DARKLUA_TYPE_B = {
	__index: Parser__DARKLUA_TYPE_B,
	name: Name__DARKLUA_TYPE_g<Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A>,
	description: Description__DARKLUA_TYPE_h<Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A>,
	epilog: Epilog__DARKLUA_TYPE_m<Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A>,
	require_command: Require_command__DARKLUA_TYPE_o<Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A>,

	action: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, fn: (...any) -> ...any) -> Parser__DARKLUA_TYPE_B,
	parse: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, argv: { [number]: string }?) -> ArgsPras__DARKLUA_TYPE_a,
	pparse: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, args: { [number]: string }?) -> (boolean, ArgsPras__DARKLUA_TYPE_a),
	error: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, msg: string?) -> (),

	argument: (
		self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A,
		name: string,
		description: string?,
		default: any?,
		convert: convert__DARKLUA_TYPE_e?,
		args: args__DARKLUA_TYPE_c?
	) -> argument__DARKLUA_TYPE_u & InMutex__DARKLUA_TYPE_b,
	option: (
		self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A,
		name: string,
		description: string?,
		default: any?,
		convert: convert__DARKLUA_TYPE_e?,
		args: args__DARKLUA_TYPE_c?,
		count: count__DARKLUA_TYPE_f?
	) -> option__DARKLUA_TYPE_v & InMutex__DARKLUA_TYPE_b,
	flag: (
		self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A,
		name: string,
		description: string?,
		default: any?,
		convert: convert__DARKLUA_TYPE_e?,
		args: args__DARKLUA_TYPE_c?,
		count: count__DARKLUA_TYPE_f?
	) -> flag__DARKLUA_TYPE_w & InMutex__DARKLUA_TYPE_b,
	mutex: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, argument_or_option: InMutex__DARKLUA_TYPE_b,...InMutex__DARKLUA_TYPE_b?) -> mutex__DARKLUA_TYPE_x,
	command: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, name: string, description: string?, epilog: string?) -> command__DARKLUA_TYPE_y,
	command_target: (
		self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A,
		name: string,
		description: string?,
		epilog: string?
	) -> command_target__DARKLUA_TYPE_z,

	group: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, name: string,...InMutex__DARKLUA_TYPE_b) -> Parser__DARKLUA_TYPE_B,
	help_max_width: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, number) -> Parser__DARKLUA_TYPE_B,
	usage_margin: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, number) -> Parser__DARKLUA_TYPE_B,
	help_usage_margin: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, number) -> Parser__DARKLUA_TYPE_B,
	help_description_margin: (self: Parser__DARKLUA_TYPE_B | __callPlusType__DARKLUA_TYPE_A, number) -> Parser__DARKLUA_TYPE_B,
}

type Set__DARKLUA_TYPE_C<T> = { [T]: true }

type reduceFromFirstValue__DARKLUA_TYPE_D = <T>(
    array: { T },
    reducer: (accumulator: T, value: T, index: number) -> T
) -> T?

type reduceWithAccumulator__DARKLUA_TYPE_E = <T, A>(
    array: { T },
    reducer: (accumulator: A, value: T, index: number) -> A,
    accumulator: A
) -> A

type alternate1__DARKLUA_TYPE_F = <A>({ A }) -> { A }

type alternate2__DARKLUA_TYPE_G = <A, B>({ A }, { B }) -> { A | B }

type alternate3__DARKLUA_TYPE_H = <A, B, C>({ A }, { B }, { C }) -> { A | B | C }

type alternateAll__DARKLUA_TYPE_I = <T, U, V...>({ T },V...) -> { U }

type KeyElement__DARKLUA_TYPE_J<K, V> = { key: K, element: V }

type zip1__DARKLUA_TYPE_K = <A>({ A }) -> { { A } }

type zip2__DARKLUA_TYPE_L = <A, B>({ A }, { B }) -> { { A | B } }

type zip3__DARKLUA_TYPE_M = <A, B, C>({ A }, { B }, { C }) -> { { A | B | C } }

type zipAll__DARKLUA_TYPE_N = <T, U>({ T },...{ U }) -> { { T | U } }

type EntriesFn__DARKLUA_TYPE_O =
    (<K, V>(map: { [K]: V }) -> { { K | V } })
    & (<K, V, T, U>(map: { [K]: V }, keyIndex: T, valueIndex: U) -> { { [(T | U)]: K | V } })

type merge1__DARKLUA_TYPE_P = <A>(A) -> A

type merge2__DARKLUA_TYPE_Q = <A, B>(A, B) -> A & B

type merge3__DARKLUA_TYPE_R = <A, B, C>(A, B, C) -> A & B & C

type merge4__DARKLUA_TYPE_S = <A, B, C, D>(A, B, C, D) -> A & B & C & D

type merge5__DARKLUA_TYPE_T = <A, B, C, D, E>(A, B, C, D, E) -> A & B & C & D & E

type mergeAll__DARKLUA_TYPE_U = <T, U, V...>(T,V...) -> U

type Set__DARKLUA_TYPE_V<T> = Set__DARKLUA_TYPE_C<T>

type Set__DARKLUA_TYPE_W<T> = Set__DARKLUA_TYPE_C<T>

type Set__DARKLUA_TYPE_X<T> = Set__DARKLUA_TYPE_W<T>

type PrefixEnum__DARKLUA_TYPE_Y =
    { type: 'Verbatim', value: string }
    | { type: 'VerbatimUNC', hostName: string, shareName: string }
    | { type: 'VerbatimDisk', value: string }
    | { type: 'DeviceNS', value: string }
    | { type: 'UNC', hostName: string, shareName: string }
    | { type: 'Disk', value: string }

type Prefix__DARKLUA_TYPE_Z = PrefixEnum__DARKLUA_TYPE_Y & {
    len: (self: Prefix__DARKLUA_TYPE_Z) -> number,
    isVerbatim: (self: Prefix__DARKLUA_TYPE_Z) -> boolean,
    isDrive: (self: Prefix__DARKLUA_TYPE_Z) -> boolean,
    hasImplicitRoot: (self: Prefix__DARKLUA_TYPE_Z) -> boolean,

    clone: (self: Prefix__DARKLUA_TYPE_Z) -> Prefix__DARKLUA_TYPE_Z,
    equal: (self: Prefix__DARKLUA_TYPE_Z, other: Prefix__DARKLUA_TYPE_Z) -> boolean,
}

type PrefixStatic__DARKLUA_TYPE__ = Prefix__DARKLUA_TYPE_Z & {
    Verbatim: (value: string) -> Prefix__DARKLUA_TYPE_Z,
    VerbatimUNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_Z,
    VerbatimDisk: (value: string) -> Prefix__DARKLUA_TYPE_Z,
    DeviceNS: (value: string) -> Prefix__DARKLUA_TYPE_Z,
    UNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_Z,
    Disk: (value: string) -> Prefix__DARKLUA_TYPE_Z,
}

type PrefixParserSlice__DARKLUA_TYPE_0 = {
    stripPrefix: (self: PrefixParserSlice__DARKLUA_TYPE_0, prefix: string) -> PrefixParserSlice__DARKLUA_TYPE_0?,
    prefixBytes: (self: PrefixParserSlice__DARKLUA_TYPE_0) -> string,
    finish: (self: PrefixParserSlice__DARKLUA_TYPE_0) -> string,
}

type Private__DARKLUA_TYPE_1 = {
    _path: string,
    _prefix: string,
    _index: number,
}

type PrivatePrefixParserSlice__DARKLUA_TYPE_2 = PrefixParserSlice__DARKLUA_TYPE_0 & Private__DARKLUA_TYPE_1

type PrefixParserSliceStatic__DARKLUA_TYPE_3 = PrefixParserSlice__DARKLUA_TYPE_0 & Private__DARKLUA_TYPE_1 & {
    new: (path: string, prefix: string) -> PrefixParserSlice__DARKLUA_TYPE_0,
}

type PrefixParserSlice__DARKLUA_TYPE_4 = PrefixParserSlice__DARKLUA_TYPE_0
type PrefixParser__DARKLUA_TYPE_5 = {
    asSlice: (self: PrefixParser__DARKLUA_TYPE_5) -> PrefixParserSlice__DARKLUA_TYPE_4,
}

type Private__DARKLUA_TYPE_6 = {
    _path: string,
    _prefix: string,
    _length: number,
}

type PrivatePrefixParser__DARKLUA_TYPE_7 = PrefixParser__DARKLUA_TYPE_5 & Private__DARKLUA_TYPE_6

type PrefixParserStatic__DARKLUA_TYPE_8 = PrefixParser__DARKLUA_TYPE_5 & Private__DARKLUA_TYPE_6 & {
    new: (path: string, length: number) -> PrefixParser__DARKLUA_TYPE_5,
    getPrefix: (path: string, length: number) -> string,
}

type Prefix__DARKLUA_TYPE_9 = Prefix__DARKLUA_TYPE_Z
type PrefixParser__DARKLUA_TYPE_aa = PrefixParser__DARKLUA_TYPE_5
type Prefix__DARKLUA_TYPE_ab = Prefix__DARKLUA_TYPE_Z
type Prefix__DARKLUA_TYPE_ac = Prefix__DARKLUA_TYPE_Z
type PrefixComponent__DARKLUA_TYPE_ad = {
    type: 'prefix',
    raw: string,
    parsed: Prefix__DARKLUA_TYPE_ac,
}

type NormalComponent__DARKLUA_TYPE_ae = { type: 'normal', value: string }

type ComponentEnum__DARKLUA_TYPE_af =
    NormalComponent__DARKLUA_TYPE_ae
    | { type: 'rootDir' }
    | { type: 'curDir' }
    | { type: 'parentDir' }
    | PrefixComponent__DARKLUA_TYPE_ad

type ComponentCommon__DARKLUA_TYPE_ag = {
    toString: (self: Component__DARKLUA_TYPE_ah) -> string,
    equal: (self: Component__DARKLUA_TYPE_ah, other: Component__DARKLUA_TYPE_ah) -> boolean,
}

type Component__DARKLUA_TYPE_ah = ComponentEnum__DARKLUA_TYPE_af & ComponentCommon__DARKLUA_TYPE_ag

type ComponentStatic__DARKLUA_TYPE_ai = Component__DARKLUA_TYPE_ah & {
    normal: (value: string) -> Component__DARKLUA_TYPE_ah,
    rootDir: () -> Component__DARKLUA_TYPE_ah,
    curDir: () -> Component__DARKLUA_TYPE_ah,
    parentDir: () -> Component__DARKLUA_TYPE_ah,
    prefix: (raw: string, prefix: Prefix__DARKLUA_TYPE_ac) -> Component__DARKLUA_TYPE_ah,
}

type Rev__DARKLUA_TYPE_aj<T> = {
    next: (self: Rev__DARKLUA_TYPE_aj<T>) -> T?,
    collect: (self: Rev__DARKLUA_TYPE_aj<T>) -> { T },
    rev: (self: Rev__DARKLUA_TYPE_aj<T>) -> Rev__DARKLUA_TYPE_aj<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev__DARKLUA_TYPE_aj<T>) -> T?,

    clone: (self: Rev__DARKLUA_TYPE_aj<T>) -> Rev__DARKLUA_TYPE_aj<T>,
}

type DoubleEndedIterator__DARKLUA_TYPE_ak<T> = {
    next: (self: DoubleEndedIterator__DARKLUA_TYPE_ak<T>) -> T?,
    nextBack: (self: DoubleEndedIterator__DARKLUA_TYPE_ak<T>) -> T?,

    clone: (self: DoubleEndedIterator__DARKLUA_TYPE_ak<T>) -> DoubleEndedIterator__DARKLUA_TYPE_ak<T>,
}

type Private__DARKLUA_TYPE_al<T> = {
    _iter: DoubleEndedIterator__DARKLUA_TYPE_ak<T>,
}

type PrivateRev__DARKLUA_TYPE_am<T> = Rev__DARKLUA_TYPE_aj<T> & Private__DARKLUA_TYPE_al<T>

type RevStatic__DARKLUA_TYPE_an = {
    new: <T>(iter: DoubleEndedIterator__DARKLUA_TYPE_ak<T>) -> Rev__DARKLUA_TYPE_aj<T>,

    next: <T>(self: Rev__DARKLUA_TYPE_aj<T>) -> T?,
    collect: <T>(self: Rev__DARKLUA_TYPE_aj<T>) -> { T },
    rev: <T>(self: Rev__DARKLUA_TYPE_aj<T>) -> Rev__DARKLUA_TYPE_aj<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev__DARKLUA_TYPE_aj<T>) -> T?,

    clone: <T>(self: Rev__DARKLUA_TYPE_aj<T>) -> Rev__DARKLUA_TYPE_aj<T>,
}

type Component__DARKLUA_TYPE_ao = Component__DARKLUA_TYPE_ah
type Prefix__DARKLUA_TYPE_ap = Prefix__DARKLUA_TYPE_Z
type Rev__DARKLUA_TYPE_aq<T> = Rev__DARKLUA_TYPE_aj<T>

type char__DARKLUA_TYPE_ar = string

type Components__DARKLUA_TYPE_as = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix__DARKLUA_TYPE_ap?,

    prefixLen: (self: Components__DARKLUA_TYPE_as) -> number,
    prefixVerbatim: (self: Components__DARKLUA_TYPE_as) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components__DARKLUA_TYPE_as) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components__DARKLUA_TYPE_as) -> number,
    -- is the iteration complete?
    finished: (self: Components__DARKLUA_TYPE_as) -> boolean,
    isSepByte: (self: Components__DARKLUA_TYPE_as, b: char__DARKLUA_TYPE_ar) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components__DARKLUA_TYPE_as) -> string,
    hasRoot: (self: Components__DARKLUA_TYPE_as) -> boolean,
    includeCurDir: (self: Components__DARKLUA_TYPE_as) -> boolean,
    parseSingleComponent: (self: Components__DARKLUA_TYPE_as, comp: string) -> Component__DARKLUA_TYPE_ao?,
    parseNextComponent: (self: Components__DARKLUA_TYPE_as) -> (number, Component__DARKLUA_TYPE_ao?),
    parseNextComponentBack: (self: Components__DARKLUA_TYPE_as) -> (number, Component__DARKLUA_TYPE_ao?),
    trimLeft: (self: Components__DARKLUA_TYPE_as) -> (),
    trimRight: (self: Components__DARKLUA_TYPE_as) -> (),

    -- Iterator
    next: (self: Components__DARKLUA_TYPE_as) -> Component__DARKLUA_TYPE_ao?,
    collect: (self: Components__DARKLUA_TYPE_as) -> { Component__DARKLUA_TYPE_ao },
    rev: (self: Components__DARKLUA_TYPE_as) -> Rev__DARKLUA_TYPE_aq<Component__DARKLUA_TYPE_ao>,
    -- DoubleEndedIterator
    nextBack: (self: Components__DARKLUA_TYPE_as) -> Component__DARKLUA_TYPE_ao?,

    -- Clone
    clone: (self: Components__DARKLUA_TYPE_as) -> Components__DARKLUA_TYPE_as,
    equal: (self: Components__DARKLUA_TYPE_as, other: Components__DARKLUA_TYPE_as) -> boolean,
}

type IterComponents__DARKLUA_TYPE_at = (items: { Component__DARKLUA_TYPE_ao }, index: number?) -> (number?, Component__DARKLUA_TYPE_ao)

type State__DARKLUA_TYPE_au = 'Prefix' | 'StartDir' | 'Body' | 'Done'

type Private__DARKLUA_TYPE_av = {
    -- The path left to parse components from
    _path: string,

    -- true if path *physically* has a root separator; for most Windows
    -- prefixes, it may have a "logical" root separator for the purposes of
    -- normalization, e.g., \\server\share == \\server\share\.
    _hasPhysicalRoot: boolean,

    -- The iterator is double-ended, and these two states keep track of what has
    -- been produced from either end
    _front: State__DARKLUA_TYPE_au,
    _back: State__DARKLUA_TYPE_au,
}

type PrivateComponents__DARKLUA_TYPE_aw = Components__DARKLUA_TYPE_as & Private__DARKLUA_TYPE_av

type ComponentsStatic__DARKLUA_TYPE_ax = Components__DARKLUA_TYPE_as & Private__DARKLUA_TYPE_av & {
    new: (path: string, prefix: Prefix__DARKLUA_TYPE_ap?, hasPhysicalRoot: boolean) -> Components__DARKLUA_TYPE_as,
    is: (value: unknown) -> boolean,
}

type Component__DARKLUA_TYPE_ay = Component__DARKLUA_TYPE_ah
type ComponentIterator__DARKLUA_TYPE_az = { next: (self: ComponentIterator__DARKLUA_TYPE_az) -> Component__DARKLUA_TYPE_ay? }

type Clone__DARKLUA_TYPE_aA<T> = { clone: (T) -> T }

type Component__DARKLUA_TYPE_aB = Component__DARKLUA_TYPE_ah
type Components__DARKLUA_TYPE_aC = Components__DARKLUA_TYPE_as
type Prefix__DARKLUA_TYPE_aD = Prefix__DARKLUA_TYPE_Z
type Ancestors__DARKLUA_TYPE_aE = {
    -- Iterator
    next: (self: Ancestors__DARKLUA_TYPE_aE) -> Path__DARKLUA_TYPE_aJ?,
    collect: (self: Ancestors__DARKLUA_TYPE_aE) -> { Path__DARKLUA_TYPE_aJ },
}

type AncestorsPrivate__DARKLUA_TYPE_aF = {
    _next: Path__DARKLUA_TYPE_aJ?,
}

type PrivateAncestors__DARKLUA_TYPE_aG = Ancestors__DARKLUA_TYPE_aE & AncestorsPrivate__DARKLUA_TYPE_aF

type AncestorsStatic__DARKLUA_TYPE_aH = Ancestors__DARKLUA_TYPE_aE & AncestorsPrivate__DARKLUA_TYPE_aF & {
    new: () -> Ancestors__DARKLUA_TYPE_aE,
}

type AsPath__DARKLUA_TYPE_aI = string | Path__DARKLUA_TYPE_aJ | Components__DARKLUA_TYPE_aC

type Path__DARKLUA_TYPE_aJ = {
    toString: (self: Path__DARKLUA_TYPE_aJ) -> string,

    toPathBuf: (self: Path__DARKLUA_TYPE_aJ) -> Path__DARKLUA_TYPE_aJ,
    isAbsolute: (self: Path__DARKLUA_TYPE_aJ) -> boolean,
    isRelative: (self: Path__DARKLUA_TYPE_aJ) -> boolean,
    hasRoot: (self: Path__DARKLUA_TYPE_aJ) -> boolean,
    parent: (self: Path__DARKLUA_TYPE_aJ) -> Path__DARKLUA_TYPE_aJ?,
    ancestors: (self: Path__DARKLUA_TYPE_aJ) -> Ancestors__DARKLUA_TYPE_aE,
    fileName: (self: Path__DARKLUA_TYPE_aJ) -> string?,
    stripPrefix: (self: Path__DARKLUA_TYPE_aJ, base: AsPath__DARKLUA_TYPE_aI) -> Path__DARKLUA_TYPE_aJ?,
    startsWith: (self: Path__DARKLUA_TYPE_aJ, base: AsPath__DARKLUA_TYPE_aI) -> boolean,
    endsWith: (self: Path__DARKLUA_TYPE_aJ, child: AsPath__DARKLUA_TYPE_aI) -> boolean,

    fileStem: (self: Path__DARKLUA_TYPE_aJ) -> string?,
    filePrefix: (self: Path__DARKLUA_TYPE_aJ) -> string?,
    extension: (self: Path__DARKLUA_TYPE_aJ) -> string?,
    join: (self: Path__DARKLUA_TYPE_aJ, path: AsPath__DARKLUA_TYPE_aI) -> Path__DARKLUA_TYPE_aJ,

    withFileName: (self: Path__DARKLUA_TYPE_aJ, fileName: string) -> Path__DARKLUA_TYPE_aJ,
    withExtension: (self: Path__DARKLUA_TYPE_aJ, extension: string) -> Path__DARKLUA_TYPE_aJ,
    components: (self: Path__DARKLUA_TYPE_aJ) -> Components__DARKLUA_TYPE_aC,

    equal: (self: Path__DARKLUA_TYPE_aJ, other: Path__DARKLUA_TYPE_aJ) -> boolean,

    -- PathBuf
    push: (self: Path__DARKLUA_TYPE_aJ, path: AsPath__DARKLUA_TYPE_aI) -> (),
    pop: (self: Path__DARKLUA_TYPE_aJ) -> boolean,
    setFileName: (self: Path__DARKLUA_TYPE_aJ, fileName: string) -> (),
    setExtension: (self: Path__DARKLUA_TYPE_aJ, extension: string) -> boolean,
    clear: (self: Path__DARKLUA_TYPE_aJ) -> (),
}

type Private__DARKLUA_TYPE_aK = {
    _inner: string,

    _prefix: (self: Path__DARKLUA_TYPE_aJ) -> Prefix__DARKLUA_TYPE_aD?,
}

type PrivatePath__DARKLUA_TYPE_aL = Path__DARKLUA_TYPE_aJ & Private__DARKLUA_TYPE_aK

type PathStatic__DARKLUA_TYPE_aM = Path__DARKLUA_TYPE_aJ & Private__DARKLUA_TYPE_aK & {
    from: (path: AsPath__DARKLUA_TYPE_aI) -> Path__DARKLUA_TYPE_aJ,
    new: (path: string) -> Path__DARKLUA_TYPE_aJ,
    is: (value: unknown) -> boolean,
}

type PrefixEnum__DARKLUA_TYPE_aN =
    { type: 'Verbatim', value: string }
    | { type: 'VerbatimUNC', hostName: string, shareName: string }
    | { type: 'VerbatimDisk', value: string }
    | { type: 'DeviceNS', value: string }
    | { type: 'UNC', hostName: string, shareName: string }
    | { type: 'Disk', value: string }

type Prefix__DARKLUA_TYPE_aO = PrefixEnum__DARKLUA_TYPE_aN & {
    len: (self: Prefix__DARKLUA_TYPE_aO) -> number,
    isVerbatim: (self: Prefix__DARKLUA_TYPE_aO) -> boolean,
    isDrive: (self: Prefix__DARKLUA_TYPE_aO) -> boolean,
    hasImplicitRoot: (self: Prefix__DARKLUA_TYPE_aO) -> boolean,

    clone: (self: Prefix__DARKLUA_TYPE_aO) -> Prefix__DARKLUA_TYPE_aO,
    equal: (self: Prefix__DARKLUA_TYPE_aO, other: Prefix__DARKLUA_TYPE_aO) -> boolean,
}

type PrefixStatic__DARKLUA_TYPE_aP = Prefix__DARKLUA_TYPE_aO & {
    Verbatim: (value: string) -> Prefix__DARKLUA_TYPE_aO,
    VerbatimUNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_aO,
    VerbatimDisk: (value: string) -> Prefix__DARKLUA_TYPE_aO,
    DeviceNS: (value: string) -> Prefix__DARKLUA_TYPE_aO,
    UNC: (hostName: string, shareName: string) -> Prefix__DARKLUA_TYPE_aO,
    Disk: (value: string) -> Prefix__DARKLUA_TYPE_aO,
}

type Prefix__DARKLUA_TYPE_aQ = Prefix__DARKLUA_TYPE_aO
type PrefixComponent__DARKLUA_TYPE_aR = {
    type: 'prefix',
    raw: string,
    parsed: Prefix__DARKLUA_TYPE_aQ,
}

type NormalComponent__DARKLUA_TYPE_aS = { type: 'normal', value: string }

type ComponentEnum__DARKLUA_TYPE_aT =
    NormalComponent__DARKLUA_TYPE_aS
    | { type: 'rootDir' }
    | { type: 'curDir' }
    | { type: 'parentDir' }
    | PrefixComponent__DARKLUA_TYPE_aR

type ComponentCommon__DARKLUA_TYPE_aU = {
    toString: (self: Component__DARKLUA_TYPE_aV) -> string,
    equal: (self: Component__DARKLUA_TYPE_aV, other: Component__DARKLUA_TYPE_aV) -> boolean,
}

type Component__DARKLUA_TYPE_aV = ComponentEnum__DARKLUA_TYPE_aT & ComponentCommon__DARKLUA_TYPE_aU

type ComponentStatic__DARKLUA_TYPE_aW = Component__DARKLUA_TYPE_aV & {
    normal: (value: string) -> Component__DARKLUA_TYPE_aV,
    rootDir: () -> Component__DARKLUA_TYPE_aV,
    curDir: () -> Component__DARKLUA_TYPE_aV,
    parentDir: () -> Component__DARKLUA_TYPE_aV,
    prefix: (raw: string, prefix: Prefix__DARKLUA_TYPE_aQ) -> Component__DARKLUA_TYPE_aV,
}

type Rev__DARKLUA_TYPE_aX<T> = {
    next: (self: Rev__DARKLUA_TYPE_aX<T>) -> T?,
    collect: (self: Rev__DARKLUA_TYPE_aX<T>) -> { T },
    rev: (self: Rev__DARKLUA_TYPE_aX<T>) -> Rev__DARKLUA_TYPE_aX<T>,
    -- DoubleEndedIterator
    nextBack: (self: Rev__DARKLUA_TYPE_aX<T>) -> T?,

    clone: (self: Rev__DARKLUA_TYPE_aX<T>) -> Rev__DARKLUA_TYPE_aX<T>,
}

type DoubleEndedIterator__DARKLUA_TYPE_aY<T> = {
    next: (self: DoubleEndedIterator__DARKLUA_TYPE_aY<T>) -> T?,
    nextBack: (self: DoubleEndedIterator__DARKLUA_TYPE_aY<T>) -> T?,

    clone: (self: DoubleEndedIterator__DARKLUA_TYPE_aY<T>) -> DoubleEndedIterator__DARKLUA_TYPE_aY<T>,
}

type Private__DARKLUA_TYPE_aZ<T> = {
    _iter: DoubleEndedIterator__DARKLUA_TYPE_aY<T>,
}

type PrivateRev__DARKLUA_TYPE_a_<T> = Rev__DARKLUA_TYPE_aX<T> & Private__DARKLUA_TYPE_aZ<T>

type RevStatic__DARKLUA_TYPE_a0 = {
    new: <T>(iter: DoubleEndedIterator__DARKLUA_TYPE_aY<T>) -> Rev__DARKLUA_TYPE_aX<T>,

    next: <T>(self: Rev__DARKLUA_TYPE_aX<T>) -> T?,
    collect: <T>(self: Rev__DARKLUA_TYPE_aX<T>) -> { T },
    rev: <T>(self: Rev__DARKLUA_TYPE_aX<T>) -> Rev__DARKLUA_TYPE_aX<T>,
    -- DoubleEndedIterator
    nextBack: <T>(self: Rev__DARKLUA_TYPE_aX<T>) -> T?,

    clone: <T>(self: Rev__DARKLUA_TYPE_aX<T>) -> Rev__DARKLUA_TYPE_aX<T>,
}

type Component__DARKLUA_TYPE_a1 = Component__DARKLUA_TYPE_aV
type Prefix__DARKLUA_TYPE_a2 = Prefix__DARKLUA_TYPE_aO
type Rev__DARKLUA_TYPE_a3<T> = Rev__DARKLUA_TYPE_aX<T>

type char__DARKLUA_TYPE_a4 = string

type Components__DARKLUA_TYPE_a5 = {
    -- The prefix as it was originally parsed, if any
    prefix: Prefix__DARKLUA_TYPE_a2?,

    prefixLen: (self: Components__DARKLUA_TYPE_a5) -> number,
    prefixVerbatim: (self: Components__DARKLUA_TYPE_a5) -> boolean,
    -- how much of the prefix is left from the point of view of iteration?
    prefixRemaining: (self: Components__DARKLUA_TYPE_a5) -> number,
    -- Given the iteration so far, how much of the pre-State::Body path is left?
    lenBeforeBody: (self: Components__DARKLUA_TYPE_a5) -> number,
    -- is the iteration complete?
    finished: (self: Components__DARKLUA_TYPE_a5) -> boolean,
    isSepByte: (self: Components__DARKLUA_TYPE_a5, b: char__DARKLUA_TYPE_a4) -> boolean,
    -- asPath: (self: Components) -> Path,
    asPathString: (self: Components__DARKLUA_TYPE_a5) -> string,
    hasRoot: (self: Components__DARKLUA_TYPE_a5) -> boolean,
    includeCurDir: (self: Components__DARKLUA_TYPE_a5) -> boolean,
    parseSingleComponent: (self: Components__DARKLUA_TYPE_a5, comp: string) -> Component__DARKLUA_TYPE_a1?,
    parseNextComponent: (self: Components__DARKLUA_TYPE_a5) -> (number, Component__DARKLUA_TYPE_a1?),
    parseNextComponentBack: (self: Components__DARKLUA_TYPE_a5) -> (number, Component__DARKLUA_TYPE_a1?),
    trimLeft: (self: Components__DARKLUA_TYPE_a5) -> (),
    trimRight: (self: Components__DARKLUA_TYPE_a5) -> (),

    -- Iterator
    next: (self: Components__DARKLUA_TYPE_a5) -> Component__DARKLUA_TYPE_a1?,
    collect: (self: Components__DARKLUA_TYPE_a5) -> { Component__DARKLUA_TYPE_a1 },
    rev: (self: Components__DARKLUA_TYPE_a5) -> Rev__DARKLUA_TYPE_a3<Component__DARKLUA_TYPE_a1>,
    -- DoubleEndedIterator
    nextBack: (self: Components__DARKLUA_TYPE_a5) -> Component__DARKLUA_TYPE_a1?,

    -- Clone
    clone: (self: Components__DARKLUA_TYPE_a5) -> Components__DARKLUA_TYPE_a5,
    equal: (self: Components__DARKLUA_TYPE_a5, other: Components__DARKLUA_TYPE_a5) -> boolean,
}

type IterComponents__DARKLUA_TYPE_a6 = (items: { Component__DARKLUA_TYPE_a1 }, index: number?) -> (number?, Component__DARKLUA_TYPE_a1)

type State__DARKLUA_TYPE_a7 = 'Prefix' | 'StartDir' | 'Body' | 'Done'

type Component__DARKLUA_TYPE_a8 = Component__DARKLUA_TYPE_aV
type Components__DARKLUA_TYPE_a9 = Components__DARKLUA_TYPE_a5
type Prefix__DARKLUA_TYPE_ba = Prefix__DARKLUA_TYPE_aO
type Ancestors__DARKLUA_TYPE_bb = {
    -- Iterator
    next: (self: Ancestors__DARKLUA_TYPE_bb) -> Path__DARKLUA_TYPE_bd?,
    collect: (self: Ancestors__DARKLUA_TYPE_bb) -> { Path__DARKLUA_TYPE_bd },
}

type AsPath__DARKLUA_TYPE_bc = string | Path__DARKLUA_TYPE_bd | Components__DARKLUA_TYPE_a9

type Path__DARKLUA_TYPE_bd = {
    toString: (self: Path__DARKLUA_TYPE_bd) -> string,

    toPathBuf: (self: Path__DARKLUA_TYPE_bd) -> Path__DARKLUA_TYPE_bd,
    isAbsolute: (self: Path__DARKLUA_TYPE_bd) -> boolean,
    isRelative: (self: Path__DARKLUA_TYPE_bd) -> boolean,
    hasRoot: (self: Path__DARKLUA_TYPE_bd) -> boolean,
    parent: (self: Path__DARKLUA_TYPE_bd) -> Path__DARKLUA_TYPE_bd?,
    ancestors: (self: Path__DARKLUA_TYPE_bd) -> Ancestors__DARKLUA_TYPE_bb,
    fileName: (self: Path__DARKLUA_TYPE_bd) -> string?,
    stripPrefix: (self: Path__DARKLUA_TYPE_bd, base: AsPath__DARKLUA_TYPE_bc) -> Path__DARKLUA_TYPE_bd?,
    startsWith: (self: Path__DARKLUA_TYPE_bd, base: AsPath__DARKLUA_TYPE_bc) -> boolean,
    endsWith: (self: Path__DARKLUA_TYPE_bd, child: AsPath__DARKLUA_TYPE_bc) -> boolean,

    fileStem: (self: Path__DARKLUA_TYPE_bd) -> string?,
    filePrefix: (self: Path__DARKLUA_TYPE_bd) -> string?,
    extension: (self: Path__DARKLUA_TYPE_bd) -> string?,
    join: (self: Path__DARKLUA_TYPE_bd, path: AsPath__DARKLUA_TYPE_bc) -> Path__DARKLUA_TYPE_bd,

    withFileName: (self: Path__DARKLUA_TYPE_bd, fileName: string) -> Path__DARKLUA_TYPE_bd,
    withExtension: (self: Path__DARKLUA_TYPE_bd, extension: string) -> Path__DARKLUA_TYPE_bd,
    components: (self: Path__DARKLUA_TYPE_bd) -> Components__DARKLUA_TYPE_a9,

    equal: (self: Path__DARKLUA_TYPE_bd, other: Path__DARKLUA_TYPE_bd) -> boolean,

    -- PathBuf
    push: (self: Path__DARKLUA_TYPE_bd, path: AsPath__DARKLUA_TYPE_bc) -> (),
    pop: (self: Path__DARKLUA_TYPE_bd) -> boolean,
    setFileName: (self: Path__DARKLUA_TYPE_bd, fileName: string) -> (),
    setExtension: (self: Path__DARKLUA_TYPE_bd, extension: string) -> boolean,
    clear: (self: Path__DARKLUA_TYPE_bd) -> (),
}

type Path__DARKLUA_TYPE_be = Path__DARKLUA_TYPE_bd
type AsPath__DARKLUA_TYPE_bf = AsPath__DARKLUA_TYPE_bc
type Component__DARKLUA_TYPE_bg = ComponentStatic__DARKLUA_TYPE_aW
type Path__DARKLUA_TYPE_bh = Path__DARKLUA_TYPE_be
type AsPath__DARKLUA_TYPE_bi = AsPath__DARKLUA_TYPE_bf
type Path__DARKLUA_TYPE_bj  = Path__DARKLUA_TYPE_bh
type AsPath__DARKLUA_TYPE_bk  = AsPath__DARKLUA_TYPE_bi
type Range__DARKLUA_TYPE_bl = { min: number?, minExclusive: boolean, max: number?, maxExclusive: boolean }

type RangeIn__DARKLUA_TYPE_bm = { min: number?, minExclusive: boolean?, max: number?, maxExclusive: boolean? }

type RangeInput__DARKLUA_TYPE_bn = string | number | RangeIn__DARKLUA_TYPE_bm

type Cause__DARKLUA_TYPE_bo = {
	ok: boolean,

	encompassingType: Type__DARKLUA_TYPE_bt?,

	errs: {
		{
			type: Type__DARKLUA_TYPE_bt,
			input: any?,
			message: string?,
		}
	},

	formatErr: (_self: any?) -> string,
}

type CauseMt__DARKLUA_TYPE_bp = {
	__tostring: (self: any) -> string,
}

type Packed__DARKLUA_TYPE_bq = { n: number, [number]: any }

type TypeMt__DARKLUA_TYPE_br = {
	__index: {
		matches: (self: any,...any) -> (boolean, Cause__DARKLUA_TYPE_bo),
		assert: (self: any,...any) -> ...any,

		format: (self: any) -> string,
		formatErr: (self: any, cause: any, values: Packed__DARKLUA_TYPE_bq?) -> string,
	},

	__call: (self: any,...any) -> (boolean, string?),

	__tostring: (self: any) -> string,
}

type TypeRaw__DARKLUA_TYPE_bs = {
	kind: string,

	meta: {
		[string]: any,
	}?,

	_matches: (...any) -> Cause__DARKLUA_TYPE_bo,
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
		type: Type__DARKLUA_TYPE_bt?,
		name: string,
		typechecker: (any) -> (boolean, any?),
	}?,

	number: {
		range: Range__DARKLUA_TYPE_bl?,
		integer: boolean?,
	}?,

	string: {
		pattern: string?,
		bytes: Range__DARKLUA_TYPE_bl?,
		graphemes: Range__DARKLUA_TYPE_bl?,
		unicode: boolean?,
	}?,

	thread: {
		status: { [CoroutineStatus__DARKLUA_TYPE_bu]: boolean }?,
	}?,

	instanceIsA: {
		class: string,
	}?,

	literal: {
		value: any,
	}?,

	tuple: {
		contents: { Type__DARKLUA_TYPE_bt },
		vararg: Type__DARKLUA_TYPE_bt?,
	}?,

	vararg: {
		type: Type__DARKLUA_TYPE_bt,
		length: Range__DARKLUA_TYPE_bl?,
	}?,

	fn: {
		args: Type__DARKLUA_TYPE_bt,
		returns: Type__DARKLUA_TYPE_bt,
	}?,

	table: {
		contents: { [string]: Type__DARKLUA_TYPE_bt },
		indexer: { key: Type__DARKLUA_TYPE_bt, value: Type__DARKLUA_TYPE_bt }?,

		array: boolean?,
		count: Range__DARKLUA_TYPE_bl?,
		raw: boolean?,
	}?,

	intersection: {
		contents: { Type__DARKLUA_TYPE_bt },
	}?,
	union: {
		contents: { Type__DARKLUA_TYPE_bt },
		optional: boolean?,
	}?,
}

type Type__DARKLUA_TYPE_bt = typeof(setmetatable({} :: TypeRaw__DARKLUA_TYPE_bs, {} :: TypeMt__DARKLUA_TYPE_br))

type CoroutineStatus__DARKLUA_TYPE_bu = "dead" | "normal" | "running" | "suspended"

type TuplePacked__DARKLUA_TYPE_bv<T...> = () -> T...

type UnionType__DARKLUA_TYPE_bw =
	(<T1, T2>(T1, T2) -> T1 | T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 | T2 | T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 | T2 | T3 | T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 | T2 | T3 | T4 | T5)
	& (<T>(...T) -> T)

type IntersectionType__DARKLUA_TYPE_bx =
	(<T1, T2>(T1, T2) -> T1 & T2)
	& (<T1, T2, T3>(T1, T2, T3) -> T1 & T2 & T3)
	& (<T1, T2, T3, T4>(T1, T2, T3, T4) -> T1 & T2 & T3 & T4)
	& (<T1, T2, T3, T4, T5>(T1, T2, T3, T4, T5) -> T1 & T2 & T3 & T4 & T5)
	& (<T>(...T) -> T)

type BuiltType__DARKLUA_TYPE_by<T...= ...any> = Type__DARKLUA_TYPE_bt & { __getType: () -> T...} & typeof(BuiltType)

type Cause__DARKLUA_TYPE_bz = Cause__DARKLUA_TYPE_bo
type Type__DARKLUA_TYPE_bA = Type__DARKLUA_TYPE_bt
type TuplePacked__DARKLUA_TYPE_bB<T...> = TuplePacked__DARKLUA_TYPE_bv<T...>

type Cause__DARKLUA_TYPE_bC  = Cause__DARKLUA_TYPE_bz
type Type__DARKLUA_TYPE_bD  = Type__DARKLUA_TYPE_bA
type TuplePacked__DARKLUA_TYPE_bE<T...> = TuplePacked__DARKLUA_TYPE_bB<T...>

type Components__DARKLUA_TYPE_bF = typeof(Path.new(""):components())

type Component__DARKLUA_TYPE_bG = typeof(Path.new(""):components():collect()[1])

type Contents__DARKLUA_TYPE_bH = typeof(ContentsType:type())

type Component__DARKLUA_TYPE_bI = Component__DARKLUA_TYPE_bG
type Components__DARKLUA_TYPE_bJ = Components__DARKLUA_TYPE_bF
type AsPath__DARKLUA_TYPE_bK = AsPath__DARKLUA_TYPE_bk
type Path__DARKLUA_TYPE_bL = Path__DARKLUA_TYPE_bj
type PeekableComponents__DARKLUA_TYPE_bM = typeof(setmetatable(
	{} :: {
		iter: Components__DARKLUA_TYPE_bJ,
		peeked: Component__DARKLUA_TYPE_bI | false,
	},
	{} :: PeekableComponentsImpl__DARKLUA_TYPE_bN
))

type PeekableComponentsImpl__DARKLUA_TYPE_bN = {
	__index: PeekableComponentsImpl__DARKLUA_TYPE_bN,
	peek: (self: PeekableComponents__DARKLUA_TYPE_bM) -> Component__DARKLUA_TYPE_bI?,
	next: (self: PeekableComponents__DARKLUA_TYPE_bM) -> Component__DARKLUA_TYPE_bI?,
}

type Path__DARKLUA_TYPE_bO = Path__DARKLUA_TYPE_bj
type AsPath__DARKLUA_TYPE_bP = AsPath__DARKLUA_TYPE_bk
type DirectoryPath__DARKLUA_TYPE_bQ = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: DirectoryPathImpl__DARKLUA_TYPE_bR
))

type DirectoryPathImpl__DARKLUA_TYPE_bR = {
	__index: DirectoryPathImpl__DARKLUA_TYPE_bR,
	__tostring: (self: DirectoryPath__DARKLUA_TYPE_bQ) -> string,
	new: (dirPath: typeof(AsPathType:type())) -> DirectoryPath__DARKLUA_TYPE_bQ,
	fromExisting: (dirPath: typeof(AsPathType:type())) -> DirectoryPath__DARKLUA_TYPE_bQ,
	withDirWritten: (self: DirectoryPath__DARKLUA_TYPE_bQ, allowOverwrite: typeof(optionalBooleanType:type())) -> DirectoryPath__DARKLUA_TYPE_bQ,
	is: (value: any) -> boolean,
	isDir: (self: DirectoryPath__DARKLUA_TYPE_bQ) -> typeof(booleanType:type()),
	readDir: (self: DirectoryPath__DARKLUA_TYPE_bQ) -> typeof(arrayOfStringType:type()),
	writeDir: (self: DirectoryPath__DARKLUA_TYPE_bQ) -> (),
	removeDir: (self: DirectoryPath__DARKLUA_TYPE_bQ) -> (),
}

type FilePath__DARKLUA_TYPE_bS = typeof(setmetatable(
	{} :: {
		path: typeof(PathType:type()),
	},
	{} :: FilePathImpl__DARKLUA_TYPE_bT)
)

type FilePathImpl__DARKLUA_TYPE_bT = {
	__index: FilePathImpl__DARKLUA_TYPE_bT,
	__tostring: (self: FilePath__DARKLUA_TYPE_bS) -> string,
	new: (filePath: typeof(AsPathType:type())) -> FilePath__DARKLUA_TYPE_bS,
	fromExisting: (filePath: typeof(AsPathType:type())) -> FilePath__DARKLUA_TYPE_bS,
	withFileWritten: (
		self: FilePath__DARKLUA_TYPE_bS,
		contents: typeof(ContentsType:type()),
		allowOverwrite: typeof(optionalBooleanType:type())
	) -> FilePath__DARKLUA_TYPE_bS,
	is: (value: any) -> boolean,
	isFile: (self: FilePath__DARKLUA_TYPE_bS) -> typeof(booleanType:type()),
	readFile: (self: FilePath__DARKLUA_TYPE_bS) -> typeof(stringType:type()),
	writeFile: (self: FilePath__DARKLUA_TYPE_bS, contents: typeof(ContentsType:type())) -> (),
	removeFile: (self: FilePath__DARKLUA_TYPE_bS) -> (),
}

type DirectoryPath__DARKLUA_TYPE_bU = DirectoryPath__DARKLUA_TYPE_bQ
type FilePath__DARKLUA_TYPE_bV = FilePath__DARKLUA_TYPE_bS
type Metadata__DARKLUA_TYPE_bW = luneFileSystem.Metadata

type MetadataKind__DARKLUA_TYPE_bX = luneFileSystem.MetadataKind

type MetadataPermissions__DARKLUA_TYPE_bY = luneFileSystem.MetadataPermissions

type WriteOptions__DARKLUA_TYPE_bZ = luneFileSystem.WriteOptions

type Components__DARKLUA_TYPE_b_ = Components__DARKLUA_TYPE_bF
type Path__DARKLUA_TYPE_b0 = Path__DARKLUA_TYPE_bj
type AsPath__DARKLUA_TYPE_b1 = AsPath__DARKLUA_TYPE_bk
type Component__DARKLUA_TYPE_b2 = Component__DARKLUA_TYPE_bG
type DirEntry__DARKLUA_TYPE_b3 = {
	name: string,
	file: FilePath__DARKLUA_TYPE_bV?,
	dir: DirectoryPath__DARKLUA_TYPE_bU?,
	path: Path__DARKLUA_TYPE_b0,
}

type ObserveState__DARKLUA_TYPE_b4 = "__inflight__" | "__dead__"

type EntryValue__DARKLUA_TYPE_b5 = {
	stateOrCleanup: ObserveState__DARKLUA_TYPE_b4 | (() -> ())?,
	entry: DirEntry__DARKLUA_TYPE_b3,
}

type DirectoryPath__DARKLUA_TYPE_b6  = DirectoryPath__DARKLUA_TYPE_bU
type FilePath__DARKLUA_TYPE_b7  = FilePath__DARKLUA_TYPE_bV
type Metadata__DARKLUA_TYPE_b8  = Metadata__DARKLUA_TYPE_bW
type MetadataKind__DARKLUA_TYPE_b9  = MetadataKind__DARKLUA_TYPE_bX
type MetadataPermissions__DARKLUA_TYPE_ca  = MetadataPermissions__DARKLUA_TYPE_bY
type WriteOptions__DARKLUA_TYPE_cb  = WriteOptions__DARKLUA_TYPE_bZ
type Components__DARKLUA_TYPE_cc  = Components__DARKLUA_TYPE_b_
type Path__DARKLUA_TYPE_cd  = Path__DARKLUA_TYPE_b0
type AsPath__DARKLUA_TYPE_ce  = AsPath__DARKLUA_TYPE_b1
type Component__DARKLUA_TYPE_cf  = Component__DARKLUA_TYPE_b2
type DirEntry__DARKLUA_TYPE_cg  = DirEntry__DARKLUA_TYPE_b3
type StyLer__DARKLUA_TYPE_ch = typeof(setmetatable({} :: {
    open: string,
    close: string,
}, {} :: {
    __call: (self: StyLer__DARKLUA_TYPE_ch, str: string) -> (string),
    __concat: (self: StyLer__DARKLUA_TYPE_ch, other: { 
        open: string, 
        close: string 
    }) -> (StyLer__DARKLUA_TYPE_ch),
}))

type CreateStyler__DARKLUA_TYPE_ci = (open: string, close: string) -> ()

type Chalk__DARKLUA_TYPE_cj = typeof(setmetatable({} :: {
    level: number,
    reset: StyLer__DARKLUA_TYPE_ch,
    bold: StyLer__DARKLUA_TYPE_ch,
    dim: StyLer__DARKLUA_TYPE_ch,
    italic: StyLer__DARKLUA_TYPE_ch,
    underline: StyLer__DARKLUA_TYPE_ch,
    overline: StyLer__DARKLUA_TYPE_ch,
    inverse: StyLer__DARKLUA_TYPE_ch,
    hidden: StyLer__DARKLUA_TYPE_ch,
    strikethrough: StyLer__DARKLUA_TYPE_ch,
    black: StyLer__DARKLUA_TYPE_ch,
    red: StyLer__DARKLUA_TYPE_ch,
    green: StyLer__DARKLUA_TYPE_ch,
    yellow: StyLer__DARKLUA_TYPE_ch,
    blue: StyLer__DARKLUA_TYPE_ch,
    magenta: StyLer__DARKLUA_TYPE_ch,
    cyan: StyLer__DARKLUA_TYPE_ch,
    white: StyLer__DARKLUA_TYPE_ch,
    blackBright: StyLer__DARKLUA_TYPE_ch,
    gray: StyLer__DARKLUA_TYPE_ch,
    grey: StyLer__DARKLUA_TYPE_ch,
    redBright: StyLer__DARKLUA_TYPE_ch,
    greenBright: StyLer__DARKLUA_TYPE_ch,
    yellowBright: StyLer__DARKLUA_TYPE_ch,
    blueBright: StyLer__DARKLUA_TYPE_ch,
    magentaBright: StyLer__DARKLUA_TYPE_ch,
    cyanBright: StyLer__DARKLUA_TYPE_ch,
    whiteBright: StyLer__DARKLUA_TYPE_ch,
    bgBlack: StyLer__DARKLUA_TYPE_ch,
    bgRed: StyLer__DARKLUA_TYPE_ch,
    bgGreen: StyLer__DARKLUA_TYPE_ch,
    bgYellow: StyLer__DARKLUA_TYPE_ch,
    bgBlue: StyLer__DARKLUA_TYPE_ch,
    bgMagenta: StyLer__DARKLUA_TYPE_ch,
    bgCyan: StyLer__DARKLUA_TYPE_ch,
    bgWhite: StyLer__DARKLUA_TYPE_ch,
    bgBlackBright: StyLer__DARKLUA_TYPE_ch,
    bgGray: StyLer__DARKLUA_TYPE_ch,
    bgGrey: StyLer__DARKLUA_TYPE_ch,
    bgRedBright: StyLer__DARKLUA_TYPE_ch,
    bgGreenBright: StyLer__DARKLUA_TYPE_ch,
    bgYellowBright: StyLer__DARKLUA_TYPE_ch,
    bgBlueBright: StyLer__DARKLUA_TYPE_ch,
    bgMagentaBright: StyLer__DARKLUA_TYPE_ch,
    bgCyanBright: StyLer__DARKLUA_TYPE_ch,
    bgWhiteBright: StyLer__DARKLUA_TYPE_ch,

    rgb: (red: number, green: number, blue: number) -> StyLer__DARKLUA_TYPE_ch,
    bgRgb: (red: number, green: number, blue: number) -> StyLer__DARKLUA_TYPE_ch,

    hex: (hex: string) -> StyLer__DARKLUA_TYPE_ch,
    bgHex: (hex: string) -> StyLer__DARKLUA_TYPE_ch,

    ansi: (ansi: number) -> StyLer__DARKLUA_TYPE_ch,
    bgAnsi: (ansi: number) -> StyLer__DARKLUA_TYPE_ch,
    ansi256: (ansi: number) -> StyLer__DARKLUA_TYPE_ch,
    bgAnsi256: (ansi: number) -> StyLer__DARKLUA_TYPE_ch,
}, {} :: {
    __call: (_: any, str: string) -> (string),
}))

type StyLer__DARKLUA_TYPE_ck = StyLer__DARKLUA_TYPE_ch
type Chalk__DARKLUA_TYPE_cl = Chalk__DARKLUA_TYPE_cj
type StyLer__DARKLUA_TYPE_cm  = StyLer__DARKLUA_TYPE_ck
type Chalk__DARKLUA_TYPE_cn  = Chalk__DARKLUA_TYPE_cl
type LogFilter__DARKLUA_TYPE_co = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

type Config__DARKLUA_TYPE_cp = {
	scriptPath: string?,
	scriptSource: string?,
	place: string?,
	sourcemap: string?,
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	logFilter: LogFilter__DARKLUA_TYPE_co,
	cacheRequires: boolean?,
}

type OutputMessage__DARKLUA_TYPE_cq = {
	type: "output",
	executionId: string,
	level: "Print" | "Info" | "Warning" | "Error",
	body: string,
}

type DoneMessage__DARKLUA_TYPE_cr = {
	type: "done",
	executionId: string,
	result: string?,
}

type LogFilter__DARKLUA_TYPE_cs = {
	enableWarn: boolean,
	enableError: boolean,
	enableInfo: boolean,
	enableOutput: boolean,
	enableLogs: boolean,
}

type ExecConnection__DARKLUA_TYPE_ct = {
	ws: any,
	executionId: string,
	script: string,
	instancePath: string?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter__DARKLUA_TYPE_cs,
	cacheRequires: boolean?,
	queuedAt: number,

	new: (ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter__DARKLUA_TYPE_cs, cacheRequires: boolean?) -> ExecConnection__DARKLUA_TYPE_ct,
	send: (self: ExecConnection__DARKLUA_TYPE_ct, data: string) -> (),
	close: (self: ExecConnection__DARKLUA_TYPE_ct) -> (),
}

type StudioConnection__DARKLUA_TYPE_cu = {
	ws: any,
	connected: boolean,
	bitset: number,
	connectedAt: number,

	new: (ws: any, bitset: number) -> StudioConnection__DARKLUA_TYPE_cu,
	send: (self: StudioConnection__DARKLUA_TYPE_cu, data: string) -> (),
	close: (self: StudioConnection__DARKLUA_TYPE_cu) -> (),
	isConnected: (self: StudioConnection__DARKLUA_TYPE_cu) -> boolean,
}

type StudioConnection__DARKLUA_TYPE_cv = StudioConnection__DARKLUA_TYPE_cu
type ExecConnection__DARKLUA_TYPE_cw = ExecConnection__DARKLUA_TYPE_ct
type VmPipeline__DARKLUA_TYPE_cx = {
	bitset: number,
	studioId: string,
	studio: StudioConnection__DARKLUA_TYPE_cv,
	execQueue: { ExecConnection__DARKLUA_TYPE_cw },
	activeExecution: ExecConnection__DARKLUA_TYPE_cw?,

	new: (bitset: number, studioId: string, studio: StudioConnection__DARKLUA_TYPE_cv) -> VmPipeline__DARKLUA_TYPE_cx,
	enqueue: (self: VmPipeline__DARKLUA_TYPE_cx, exec: ExecConnection__DARKLUA_TYPE_cw) -> (),
	completeExecution: (self: VmPipeline__DARKLUA_TYPE_cx, executionId: string) -> (),
	forwardOutput: (self: VmPipeline__DARKLUA_TYPE_cx, executionId: string, message: string) -> (),
	disconnect: (self: VmPipeline__DARKLUA_TYPE_cx) -> (),
	getQueueLength: (self: VmPipeline__DARKLUA_TYPE_cx) -> number,
	isIdle: (self: VmPipeline__DARKLUA_TYPE_cx) -> boolean,
}

type StudioConnection__DARKLUA_TYPE_cy = StudioConnection__DARKLUA_TYPE_cu
type ExecConnection__DARKLUA_TYPE_cz = ExecConnection__DARKLUA_TYPE_ct
type VmPipeline__DARKLUA_TYPE_cA = VmPipeline__DARKLUA_TYPE_cx
type MatchingVm__DARKLUA_TYPE_cB = {
	bitset: number,
	studioId: string,
	pipeline: VmPipeline__DARKLUA_TYPE_cA,
}

type Config__DARKLUA_TYPE_cC = {
	scriptPath: string?,
	scriptSource: string?,
	sourcemap: string?,
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	filterBits: number,
	filterMask: number,
	logFilter: LogFilter__DARKLUA_TYPE_co,
	cacheRequires: boolean?,
}
local __DARKLUA_BUNDLE_MODULES={cache={}::any}do do local function __modImpl()--!nocheck


local process = require("@lune/process")
local stdio = require("@lune/stdio")

local function deep_update(t1, t2)
	for k, v in pairs(t2) do
		if type(v) == "table" then
			v = deep_update({}, v)
		end

		t1[k] = v
	end

	return t1
end

-- A property is a tuple {name, callback}.
-- properties.args is number of properties that can be set as arguments
-- when calling an object.
local function class(prototype, properties, parent)
	-- Class is the metatable of its instances.
	local cl = {}
	cl.__index = cl

	if parent then
		cl.__prototype = deep_update(deep_update({}, parent.__prototype), prototype)
	else
		cl.__prototype = prototype
	end

	if properties then
		local names = {}

		-- Create setter methods and fill set of property names.
		for _, property in ipairs(properties) do
			local name, callback = property[1], property[2]

			cl[name] = function(self, value)
				if not callback(self, value) then
					self["_" .. name] = value
				end

				return self
			end

			names[name] = true
		end

		function cl.__call(self, ...)
			-- When calling an object, if the first argument is a table,
			-- interpret keys as property names, else delegate arguments
			-- to corresponding setters in order.
			if type((...)) == "table" then
				for name, value in pairs((...)) do
					if names[name] then
						self[name](self, value)
					end
				end
			else
				local nargs = select("#", ...)

				for i, property in ipairs(properties) do
					if i > nargs or i > properties.args then
						break
					end

					local arg = select(i, ...)

					if arg ~= nil then
						self[property[1] ](self, arg)
					end
				end
			end

			return self
		end
	end

	-- If indexing class fails, fallback to its parent.
	local class_metatable = {}
	class_metatable.__index = parent

	function class_metatable.__call(self, ...)
		-- Calling a class returns its instance.
		-- Arguments are delegated to the instance.
		local object = deep_update({}, self.__prototype)
		setmetatable(object, self)
		return object(...)
	end

	return setmetatable(cl, class_metatable)
end

local function typecheck(name, types, value)
	for _, type_ in ipairs(types) do
		if type(value) == type_ then
			return true
		end
	end

	error(("bad property '%s' (%s expected, got %s)"):format(name, table.concat(types, " or "), type(value)))
end

local function typechecked(name, ...)
	local types = { ... }
	return {
		name,
		function(_, value)
			typecheck(name, types, value)
		end,
	}
end

local multiname = {
	"name",
	function(self, value)
		typecheck("name", { "string" }, value)

		for alias in value:gmatch("%S+") do
			self._name = self._name or alias
			table.insert(self._aliases, alias)
		end

		-- Do not set _name as with other properties.
		return true
	end,
}

local function parse_boundaries(str)
	if tonumber(str) then
		return tonumber(str), tonumber(str)
	end

	if str == "*" then
		return 0, math.huge
	end

	if str == "+" then
		return 1, math.huge
	end

	if str == "?" then
		return 0, 1
	end

	if str:match("^%d+%-%d+$") then
		local min, max = str:match("^(%d+)%-(%d+)$")
		return tonumber(min), tonumber(max)
	end

	if str:match("^%d+%+$") then
		local min = str:match("^(%d+)%+$")
		return tonumber(min), math.huge
	end

	return
end

local function boundaries(name)
	return {
		name,
		function(self, value)
			typecheck(name, { "number", "string" }, value)

			local min, max = parse_boundaries(value)

			if not min then
				error(("bad property '%s'"):format(name))
			end

			self["_min" .. name], self["_max" .. name] = min, max
		end,
	}
end

local actions = {}

local option_action = {
	"action",
	function(_, value)
		typecheck("action", { "function", "string" }, value)

		if type(value) == "string" and not actions[value] then
			error(("unknown action '%s'"):format(value))
		end
	end,
}

local option_init = {
	"init",
	function(self)
		self._has_init = true
	end,
}

local option_default = {
	"default",
	function(self, value)
		if type(value) ~= "string" then
			self._init = value
			self._has_init = true
			return true
		end
		return
	end,
}

local add_help = {
	"add_help",
	function(self, value)
		typecheck("add_help", { "boolean", "string", "table" }, value)

		if self._has_help then
			table.remove(self._options)
			self._has_help = false
		end

		if value then
			local help = self:flag():description("Show this help message and exit."):action(function()
				print(self:get_help())
				process.exit(0)
			end)

			if value ~= true then
				help = help(value)
			end

			if not help._name then
				help("-h")("--help")
			end

			self._has_help = true
		end
	end,
}

-- selene: allow(mixed_table)
local Parser = class({
	_arguments = {},
	_options = {},
	_commands = {},
	_mutexes = {},
	_groups = {},
	_require_command = true,
	_handle_options = true,
}, {
	args = 3,
	typechecked("name", "string"),
	typechecked("description", "string"),
	typechecked("epilog", "string"),
	typechecked("usage", "string"),
	typechecked("help", "string"),
	typechecked("require_command", "boolean"),
	typechecked("handle_options", "boolean"),
	typechecked("action", "function"),
	typechecked("command_target", "string"),
	typechecked("help_vertical_space", "number"),
	typechecked("usage_margin", "number"),
	typechecked("usage_max_width", "number"),
	typechecked("help_usage_margin", "number"),
	typechecked("help_description_margin", "number"),
	typechecked("help_max_width", "number"),
	add_help,
})

-- selene: allow(mixed_table)
local Command = class({
	_aliases = {},
}, {
	args = 3,
	multiname,
	typechecked("description", "string"),
	typechecked("epilog", "string"),
	typechecked("target", "string"),
	typechecked("usage", "string"),
	typechecked("help", "string"),
	typechecked("require_command", "boolean"),
	typechecked("handle_options", "boolean"),
	typechecked("action", "function"),
	typechecked("command_target", "string"),
	typechecked("help_vertical_space", "number"),
	typechecked("usage_margin", "number"),
	typechecked("usage_max_width", "number"),
	typechecked("help_usage_margin", "number"),
	typechecked("help_description_margin", "number"),
	typechecked("help_max_width", "number"),
	typechecked("hidden", "boolean"),
	add_help,
}, Parser)

-- selene: allow(mixed_table)
local Argument = class({
	_minargs = 1,
	_maxargs = 1,
	_mincount = 1,
	_maxcount = 1,
	_defmode = "unused",
	_show_default = true,
}, {
	args = 5,
	typechecked("name", "string"),
	typechecked("description", "string"),
	option_default,
	typechecked("convert", "function", "table"),
	boundaries("args"),
	typechecked("target", "string"),
	typechecked("defmode", "string"),
	typechecked("show_default", "boolean"),
	typechecked("argname", "string", "table"),
	typechecked("hidden", "boolean"),
	option_action,
	option_init,
})

-- selene: allow(mixed_table)
local Option = class({
	_aliases = {},
	_mincount = 0,
	_overwrite = true,
}, {
	args = 6,
	multiname,
	typechecked("description", "string"),
	option_default,
	typechecked("convert", "function", "table"),
	boundaries("args"),
	boundaries("count"),
	typechecked("target", "string"),
	typechecked("defmode", "string"),
	typechecked("show_default", "boolean"),
	typechecked("overwrite", "boolean"),
	typechecked("argname", "string", "table"),
	typechecked("hidden", "boolean"),
	option_action,
	option_init,
}, Argument)

function Parser:_inherit_property(name, default)
	local element = self

	while true do
		local value = element["_" .. name]

		if value ~= nil then
			return value
		end

		if not element._parent then
			return default
		end

		element = element._parent
	end
end

function Argument:_get_argument_list()
	local buf = {}
	local i = 1

	while i <= math.min(self._minargs, 3) do
		local argname = self:_get_argname(i)

		if self._default and self._defmode:find("a") then
			argname = "[" .. argname .. "]"
		end

		table.insert(buf, argname)
		i = i + 1
	end

	while i <= math.min(self._maxargs, 3) do
		table.insert(buf, "[" .. self:_get_argname(i) .. "]")
		i = i + 1

		if self._maxargs == math.huge then
			break
		end
	end

	if i < self._maxargs then
		table.insert(buf, "...")
	end

	return buf
end

function Argument:_get_usage()
	local usage = table.concat(self:_get_argument_list(), " ")

	if self._default and self._defmode:find("u") then
		if self._maxargs > 1 or (self._minargs == 1 and not self._defmode:find("a")) then
			usage = "[" .. usage .. "]"
		end
	end

	return usage
end

function actions.store_true(result, target)
	result[target] = true
end

function actions.store_false(result, target)
	result[target] = false
end

function actions.store(result, target, argument)
	result[target] = argument
end

function actions.count(result, target, _, overwrite)
	if not overwrite then
		result[target] = result[target] + 1
	end
end

function actions.append(result, target, argument, overwrite)
	result[target] = result[target] or {}
	table.insert(result[target], argument)

	if overwrite then
		table.remove(result[target], 1)
	end
end

function actions.concat(result, target, arguments, overwrite)
	if overwrite then
		error("'concat' action can't handle too many invocations")
	end

	result[target] = result[target] or {}

	for _, argument in ipairs(arguments) do
		table.insert(result[target], argument)
	end
end

function Argument:_get_action()
	local action, init

	if self._maxcount == 1 then
		if self._maxargs == 0 then
			action, init = "store_true", nil
		else
			action, init = "store", nil
		end
	else
		if self._maxargs == 0 then
			action, init = "count", 0
		else
			action, init = "append", {}
		end
	end

	if self._action then
		action = self._action
	end

	if self._has_init then
		init = self._init
	end

	if type(action) == "string" then
		action = actions[action]
	end

	return action, init
end

-- Returns placeholder for `narg`-th argument.
function Argument:_get_argname(narg)
	local argname = self._argname or self:_get_default_argname()

	if type(argname) == "table" then
		return argname[narg]
	else
		return argname
	end
end

function Argument:_get_default_argname()
	return "<" .. self._name .. ">"
end

function Option:_get_default_argname()
	return "<" .. self:_get_default_target() .. ">"
end

-- Returns labels to be shown in the help message.
function Argument:_get_label_lines()
	return { self._name }
end

function Option:_get_label_lines()
	local argument_list = self:_get_argument_list()

	if #argument_list == 0 then
		-- Don't put aliases for simple flags like `-h` on different lines.
		return { table.concat(self._aliases, ", ") }
	end

	local longest_alias_length = -1

	for _, alias in ipairs(self._aliases) do
		longest_alias_length = math.max(longest_alias_length, #alias)
	end

	local argument_list_repr = table.concat(argument_list, " ")
	local lines = {}

	for i, alias in ipairs(self._aliases) do
		local line = (" "):rep(longest_alias_length - #alias) .. alias .. " " .. argument_list_repr

		if i ~= #self._aliases then
			line = line .. ","
		end

		table.insert(lines, line)
	end

	return lines
end

function Command:_get_label_lines()
	return { table.concat(self._aliases, ", ") }
end

function Argument:_get_description()
	if self._default and self._show_default then
		if self._description then
			return ("%s (default: %s)"):format(self._description, self._default)
		else
			return ("default: %s"):format(self._default)
		end
	else
		return self._description or ""
	end
end

function Command:_get_description()
	return self._description or ""
end

function Option:_get_usage()
	local usage = self:_get_argument_list()
	table.insert(usage, 1, self._name)
	usage = table.concat(usage, " ")

	if self._mincount == 0 or self._default then
		usage = "[" .. usage .. "]"
	end

	return usage
end

function Argument:_get_default_target()
	return self._name
end

function Option:_get_default_target()
	local res

	for _, alias in ipairs(self._aliases) do
		if alias:sub(1, 1) == alias:sub(2, 2) then
			res = alias:sub(3)
			break
		end
	end

	res = res or self._name:sub(2)
	return (res:gsub("-", "_"))
end

function Option:_is_vararg()
	return self._maxargs ~= self._minargs
end

function Parser:_get_fullname()
	local parent = self._parent
	local buf = { self._name }

	while parent do
		table.insert(buf, 1, parent._name)
		parent = parent._parent
	end

	return table.concat(buf, " ")
end

function Parser:_update_charset(charset)
	charset = charset or {}

	for _, command in ipairs(self._commands) do
		command:_update_charset(charset)
	end

	for _, option in ipairs(self._options) do
		for _, alias in ipairs(option._aliases) do
			charset[alias:sub(1, 1)] = true
		end
	end

	return charset
end

function Parser:argument(...)
	local argument = Argument(...)
	table.insert(self._arguments, argument)
	return argument
end

function Parser:option(...)
	local option = Option(...)

	if self._has_help then
		-- stylua: ignore
		table.insert(self._options, (#self._options), option)
	else
		table.insert(self._options, option)
	end

	return option
end

function Parser:flag(...)
	return self:option():args(0)(...)
end

function Parser:command(...)
	local command = Command():add_help(true)(...)
	command._parent = self
	table.insert(self._commands, command)
	return command
end

function Parser:mutex(...)
	local elements = { ... }

	for i, element in ipairs(elements) do
		local mt = getmetatable(element)
		assert(mt == Option or mt == Argument, ("bad argument #%d to 'mutex' (Option or Argument expected)"):format(i))
	end

	table.insert(self._mutexes, elements)
	return self
end

function Parser:group(name, ...)
	assert(type(name) == "string", ("bad argument #1 to 'group' (string expected, got %s)"):format(type(name)))

	-- selene: allow(mixed_table)
	local group = { name = name, ... }

	for i, element in ipairs(group) do
		local mt = getmetatable(element)
		assert(
			mt == Option or mt == Argument or mt == Command,
			("bad argument #%d to 'group' (Option or Argument or Command expected)"):format(i + 1)
		)
	end

	table.insert(self._groups, group)
	return self
end

local usage_welcome = "Usage: "

function Parser:get_usage()
	if self._usage then
		return self._usage
	end

	local usage_margin = self:_inherit_property("usage_margin", #usage_welcome)
	local max_usage_width = self:_inherit_property("usage_max_width", 70)
	local lines = { usage_welcome .. self:_get_fullname() }

	local function add(s)
		if #lines[#lines] + 1 + #s <= max_usage_width then
			lines[#lines] = lines[#lines] .. " " .. s
		else
			lines[#lines + 1] = (" "):rep(usage_margin) .. s
		end
	end

	-- Normally options are before positional arguments in usage messages.
	-- However, vararg options should be after, because they can't be reliable used
	-- before a positional argument.
	-- Mutexes come into play, too, and are shown as soon as possible.
	-- Overall, output usages in the following order:
	-- 1. Mutexes that don't have positional arguments or vararg options.
	-- 2. Options that are not in any mutexes and are not vararg.
	-- 3. Positional arguments - on their own or as a part of a mutex.
	-- 4. Remaining mutexes.
	-- 5. Remaining options.

	local elements_in_mutexes = {}
	local added_elements = {}
	local added_mutexes = {}
	local argument_to_mutexes = {}

	local function add_mutex(mutex, main_argument)
		if added_mutexes[mutex] then
			return
		end

		added_mutexes[mutex] = true
		local buf = {}

		for _, element in ipairs(mutex) do
			if not element._hidden and not added_elements[element] then
				if getmetatable(element) == Option or element == main_argument then
					table.insert(buf, element:_get_usage())
					added_elements[element] = true
				end
			end
		end

		if #buf == 1 then
			add(buf[1])
		elseif #buf > 1 then
			add("(" .. table.concat(buf, " | ") .. ")")
		end
	end

	local function add_element(element)
		if not element._hidden and not added_elements[element] then
			add(element:_get_usage())
			added_elements[element] = true
		end
	end

	for _, mutex in ipairs(self._mutexes) do
		local is_vararg = false
		local has_argument = false

		for _, element in ipairs(mutex) do
			if getmetatable(element) == Option then
				if element:_is_vararg() then
					is_vararg = true
				end
			else
				has_argument = true
				argument_to_mutexes[element] = argument_to_mutexes[element] or {}
				table.insert(argument_to_mutexes[element], mutex)
			end

			elements_in_mutexes[element] = true
		end

		if not is_vararg and not has_argument then
			add_mutex(mutex)
		end
	end

	for _, option in ipairs(self._options) do
		if not elements_in_mutexes[option] and not option:_is_vararg() then
			add_element(option)
		end
	end

	-- Add usages for positional arguments, together with one mutex containing them, if they are in a mutex.
	for _, argument in ipairs(self._arguments) do
		-- Pick a mutex as a part of which to show this argument, take the first one that's still available.
		local mutex

		if elements_in_mutexes[argument] then
			for _, argument_mutex in ipairs(argument_to_mutexes[argument]) do
				if not added_mutexes[argument_mutex] then
					mutex = argument_mutex
				end
			end
		end

		if mutex then
			add_mutex(mutex, argument)
		else
			add_element(argument)
		end
	end

	for _, mutex in ipairs(self._mutexes) do
		add_mutex(mutex)
	end

	for _, option in ipairs(self._options) do
		add_element(option)
	end

	if #self._commands > 0 then
		if self._require_command then
			add("<command>")
		else
			add("[<command>]")
		end

		add("...")
	end

	return table.concat(lines, "\n")
end

local function split_lines(s)
	if s == "" then
		return {}
	end

	local lines = {}

	if s:sub(-1) ~= "\n" then
		s = s .. "\n"
	end

	for line in s:gmatch("([^\n]*)\n") do
		table.insert(lines, line)
	end

	return lines
end

local function autowrap_line(line, max_length)
	-- Algorithm for splitting lines is simple and greedy.
	local result_lines = {}

	-- Preserve original indentation of the line, put this at the beginning of each result line.
	-- If the first word looks like a list marker ('*', '+', or '-'), add spaces so that starts
	-- of the second and the following lines vertically align with the start of the second word.
	local indentation = line:match("^ *")

	if line:find("^ *[%*%+%-]") then
		indentation = indentation .. " " .. line:match("^ *[%*%+%-]( *)")
	end

	-- Parts of the last line being assembled.
	local line_parts = {}

	-- Length of the current line.
	local line_length = 0

	-- Index of the next character to consider.
	local index = 1

	while true do
		local word_start, word_finish, word = line:find("([^ ]+)", index)

		if not word_start then
			-- Ignore trailing spaces, if any.
			break
		end

		local preceding_spaces = line:sub(index, word_start - 1)
		index = word_finish + 1

		if (#line_parts == 0) or (line_length + #preceding_spaces + #word <= max_length) then
			-- Either this is the very first word or it fits as an addition to the current line, add it.
			table.insert(line_parts, preceding_spaces) -- For the very first word this adds the indentation.
			table.insert(line_parts, word)
			line_length = line_length + #preceding_spaces + #word
		else
			-- Does not fit, finish current line and put the word into a new one.
			table.insert(result_lines, table.concat(line_parts))
			line_parts = { indentation, word }
			line_length = #indentation + #word
		end
	end

	if #line_parts > 0 then
		table.insert(result_lines, table.concat(line_parts))
	end

	if #result_lines == 0 then
		-- Preserve empty lines.
		result_lines[1] = ""
	end

	return result_lines
end

-- Automatically wraps lines within given array,
-- attempting to limit line length to `max_length`.
-- Existing line splits are preserved.
local function autowrap(lines, max_length)
	local result_lines = {}

	for _, line in ipairs(lines) do
		local autowrapped_lines = autowrap_line(line, max_length)

		for _, autowrapped_line in ipairs(autowrapped_lines) do
			table.insert(result_lines, autowrapped_line)
		end
	end

	return result_lines
end

function Parser:_get_element_help(element)
	local label_lines = element:_get_label_lines()
	local description_lines = split_lines(element:_get_description())

	local result_lines = {}

	-- All label lines should have the same length (except the last one, it has no comma).
	-- If too long, start description after all the label lines.
	-- Otherwise, combine label and description lines.

	local usage_margin_len = self:_inherit_property("help_usage_margin", 3)
	local usage_margin = (" "):rep(usage_margin_len)
	local description_margin_len = self:_inherit_property("help_description_margin", 25)
	local description_margin = (" "):rep(description_margin_len)

	local help_max_width = self:_inherit_property("help_max_width")

	if help_max_width then
		local description_max_width = math.max(help_max_width - description_margin_len, 10)
		description_lines = autowrap(description_lines, description_max_width)
	end

	if #label_lines[1] >= (description_margin_len - usage_margin_len) then
		for _, label_line in ipairs(label_lines) do
			table.insert(result_lines, usage_margin .. label_line)
		end

		for _, description_line in ipairs(description_lines) do
			table.insert(result_lines, description_margin .. description_line)
		end
	else
		for i = 1, math.max(#label_lines, #description_lines) do
			local label_line = label_lines[i]
			local description_line = description_lines[i]

			local line = ""

			if label_line then
				line = usage_margin .. label_line
			end

			if description_line and description_line ~= "" then
				line = line .. (" "):rep(description_margin_len - #line) .. description_line
			end

			table.insert(result_lines, line)
		end
	end

	return table.concat(result_lines, "\n")
end

local function get_group_types(group)
	local types = {}

	for _, element in ipairs(group) do
		types[getmetatable(element)] = true
	end

	return types
end

function Parser:_add_group_help(blocks, added_elements, label, elements)
	local buf = { label }

	for _, element in ipairs(elements) do
		if not element._hidden and not added_elements[element] then
			added_elements[element] = true
			table.insert(buf, self:_get_element_help(element))
		end
	end

	if #buf > 1 then
		table.insert(blocks, table.concat(buf, ("\n"):rep(self:_inherit_property("help_vertical_space", 0) + 1)))
	end
end

function Parser:get_help()
	if self._help then
		return self._help
	end

	local blocks = { self:get_usage() }

	local help_max_width = self:_inherit_property("help_max_width")

	if self._description then
		local description = self._description

		if help_max_width then
			description = table.concat(autowrap(split_lines(description), help_max_width), "\n")
		end

		table.insert(blocks, description)
	end

	-- 1. Put groups containing arguments first, then other arguments.
	-- 2. Put remaining groups containing options, then other options.
	-- 3. Put remaining groups containing commands, then other commands.
	-- Assume that an element can't be in several groups.
	local groups_by_type = {
		[Argument] = {},
		[Option] = {},
		[Command] = {},
	}

	for _, group in ipairs(self._groups) do
		local group_types = get_group_types(group)

		for _, mt in ipairs({ Argument, Option, Command }) do
			if group_types[mt] then
				table.insert(groups_by_type[mt], group)
				break
			end
		end
	end

	local default_groups = {
		{ name = "Arguments", type = Argument, elements = self._arguments },
		{ name = "Options", type = Option, elements = self._options },
		{ name = "Commands", type = Command, elements = self._commands },
	}

	local added_elements = {}

	for _, default_group in ipairs(default_groups) do
		local type_groups = groups_by_type[default_group.type]

		for _, group in ipairs(type_groups) do
			self:_add_group_help(blocks, added_elements, group.name .. ":", group)
		end

		local default_label = default_group.name .. ":"

		if #type_groups > 0 then
			default_label = "Other " .. default_label:gsub("^.", string.lower)
		end

		self:_add_group_help(blocks, added_elements, default_label, default_group.elements)
	end

	if self._epilog then
		local epilog = self._epilog

		if help_max_width then
			epilog = table.concat(autowrap(split_lines(epilog), help_max_width), "\n")
		end

		table.insert(blocks, epilog)
	end

	return table.concat(blocks, "\n\n")
end

local function get_tip(context, wrong_name)
	local context_pool = {}
	local possible_name
	local possible_names = {}

	for name in pairs(context) do
		if type(name) == "string" then
			for i = 1, #name do
				possible_name = name:sub(1, i - 1) .. name:sub(i + 1)

				if not context_pool[possible_name] then
					context_pool[possible_name] = {}
				end

				table.insert(context_pool[possible_name], name)
			end
		end
	end

	for i = 1, #wrong_name + 1 do
		possible_name = wrong_name:sub(1, i - 1) .. wrong_name:sub(i + 1)

		if context[possible_name] then
			possible_names[possible_name] = true
		elseif context_pool[possible_name] then
			for _, name in ipairs(context_pool[possible_name]) do
				possible_names[name] = true
			end
		end
	end

	local first = next(possible_names)

	if first then
		if next(possible_names, first) then
			local possible_names_arr = {}

			for name in pairs(possible_names) do
				table.insert(possible_names_arr, "'" .. name .. "'")
			end

			table.sort(possible_names_arr)
			return "\nDid you mean one of these: " .. table.concat(possible_names_arr, " ") .. "?"
		else
			return "\nDid you mean '" .. first .. "'?"
		end
	else
		return ""
	end
end

local ElementState = class({
	invocations = 0,
})

function ElementState:__call(state, element)
	self.state = state
	self.result = state.result
	self.element = element
	self.target = element._target or element:_get_default_target()
	self.action, self.result[self.target] = element:_get_action()
	return self
end

function ElementState:error(fmt, ...)
	self.state:error(fmt, ...)
end

function ElementState:convert(argument, index)
	local converter = self.element._convert

	if converter then
		local ok, err

		if type(converter) == "function" then
			ok, err = converter(argument)
		elseif type(converter[index]) == "function" then
			ok, err = converter[index](argument)
		else
			ok = converter[argument]
		end

		if ok == nil then
			self:error(err and "%s" or "malformed argument '%s'", err or argument)
		end

		argument = ok
	end

	return argument
end

function ElementState:default(mode)
	return self.element._defmode:find(mode) and self.element._default
end

local function bound(noun, min, max, is_max)
	local res = ""

	if min ~= max then
		res = "at " .. (is_max and "most" or "least") .. " "
	end

	local number = is_max and max or min
	return res .. tostring(number) .. " " .. noun .. (number == 1 and "" or "s")
end

function ElementState:set_name(alias)
	self.name = ("%s '%s'"):format(alias and "option" or "argument", alias or self.element._name)
end

function ElementState:invoke()
	self.open = true
	self.overwrite = false

	if self.invocations >= self.element._maxcount then
		if self.element._overwrite then
			self.overwrite = true
		else
			local num_times_repr = bound("time", self.element._mincount, self.element._maxcount, true)
			self:error("%s must be used %s", self.name, num_times_repr)
		end
	else
		self.invocations = self.invocations + 1
	end

	self.args = {}

	if self.element._maxargs <= 0 then
		self:close()
	end

	return self.open
end

function ElementState:pass(argument)
	argument = self:convert(argument, #self.args + 1)
	table.insert(self.args, argument)

	if #self.args >= self.element._maxargs then
		self:close()
	end

	return self.open
end

function ElementState:complete_invocation()
	while #self.args < self.element._minargs do
		self:pass(self.element._default)
	end
end

function ElementState:close()
	if self.open then
		self.open = false

		if #self.args < self.element._minargs then
			if self:default("a") then
				self:complete_invocation()
			else
				if #self.args == 0 then
					if getmetatable(self.element) == Argument then
						self:error("missing %s", self.name)
					elseif self.element._maxargs == 1 then
						self:error("%s requires an argument", self.name)
					end
				end

				self:error("%s requires %s", self.name, bound("argument", self.element._minargs, self.element._maxargs))
			end
		end

		local args

		if self.element._maxargs == 0 then
			args = self.args[1]
		elseif self.element._maxargs == 1 then
			if self.element._minargs == 0 and self.element._mincount ~= self.element._maxcount then
				args = self.args
			else
				args = self.args[1]
			end
		else
			args = self.args
		end

		self.action(self.result, self.target, args, self.overwrite)
	end
end

local ParseState = class({
	result = {},
	options = {},
	arguments = {},
	argument_i = 1,
	element_to_mutexes = {},
	mutex_to_element_state = {},
	command_actions = {},
})

function ParseState:__call(parser, error_handler)
	self.parser = parser
	self.error_handler = error_handler
	self.charset = parser:_update_charset()
	self:switch(parser)
	return self
end

function ParseState:error(fmt, ...)
	self.error_handler(self.parser, fmt:format(...))
end

function ParseState:switch(parser)
	self.parser = parser

	if parser._action then
		table.insert(self.command_actions, { action = parser._action, name = parser._name })
	end

	for _, option in ipairs(parser._options) do
		option = ElementState(self, option)
		table.insert(self.options, option)

		for _, alias in ipairs(option.element._aliases) do
			self.options[alias] = option
		end
	end

	for _, mutex in ipairs(parser._mutexes) do
		for _, element in ipairs(mutex) do
			if not self.element_to_mutexes[element] then
				self.element_to_mutexes[element] = {}
			end

			table.insert(self.element_to_mutexes[element], mutex)
		end
	end

	for _, argument in ipairs(parser._arguments) do
		argument = ElementState(self, argument)
		table.insert(self.arguments, argument)
		argument:set_name()
		argument:invoke()
	end

	self.handle_options = parser._handle_options
	self.argument = self.arguments[self.argument_i]
	self.commands = parser._commands

	for _, command in ipairs(self.commands) do
		for _, alias in ipairs(command._aliases) do
			self.commands[alias] = command
		end
	end
end

function ParseState:get_option(name)
	local option = self.options[name]

	if not option then
		self:error("unknown option '%s'%s", name, get_tip(self.options, name))
		return
	else
		return option
	end
end

function ParseState:get_command(name)
	local command = self.commands[name]

	if not command then
		if #self.commands > 0 then
			self:error("unknown command '%s'%s", name, get_tip(self.commands, name))
			return
		else
			self:error("too many arguments")
			return
		end
	else
		return command
	end
end

function ParseState:check_mutexes(element_state)
	if self.element_to_mutexes[element_state.element] then
		for _, mutex in ipairs(self.element_to_mutexes[element_state.element]) do
			local used_element_state = self.mutex_to_element_state[mutex]

			if used_element_state and used_element_state ~= element_state then
				self:error("%s can not be used together with %s", element_state.name, used_element_state.name)
			else
				self.mutex_to_element_state[mutex] = element_state
			end
		end
	end
end

function ParseState:invoke(option, name)
	self:close()
	option:set_name(name)
	self:check_mutexes(option, name)

	if option:invoke() then
		self.option = option
	end
end

function ParseState:pass(arg)
	if self.option then
		if not self.option:pass(arg) then
			self.option = nil
		end
	elseif self.argument then
		self:check_mutexes(self.argument)

		if not self.argument:pass(arg) then
			self.argument_i = self.argument_i + 1
			self.argument = self.arguments[self.argument_i]
		end
	else
		local command = self:get_command(arg)
		self.result[command._target or command._name] = true

		if self.parser._command_target then
			self.result[self.parser._command_target] = command._name
		end

		self:switch(command)
	end
end

function ParseState:close()
	if self.option then
		self.option:close()
		self.option = nil
	end
end

function ParseState:finalize()
	self:close()

	for i = self.argument_i, #self.arguments do
		local argument = self.arguments[i]
		if #argument.args == 0 and argument:default("u") then
			argument:complete_invocation()
		else
			argument:close()
		end
	end

	if self.parser._require_command and #self.commands > 0 then
		self:error("a command is required")
	end

	for _, option in ipairs(self.options) do
		option.name = option.name or ("option '%s'"):format(option.element._name)

		if option.invocations == 0 then
			if option:default("u") then
				option:invoke()
				option:complete_invocation()
				option:close()
			end
		end

		local mincount = option.element._mincount

		if option.invocations < mincount then
			if option:default("a") then
				while option.invocations < mincount do
					option:invoke()
					option:close()
				end
			elseif option.invocations == 0 then
				self:error("missing %s", option.name)
			else
				self:error("%s must be used %s", option.name, bound("time", mincount, option.element._maxcount))
			end
		end
	end

	for i = #self.command_actions, 1, -1 do
		self.command_actions[i].action(self.result, self.command_actions[i].name)
	end
end

function ParseState:parse(args)
	for _, arg in ipairs(args) do
		local plain = true

		if self.handle_options then
			local first = arg:sub(1, 1)

			if self.charset[first] then
				if #arg > 1 then
					plain = false

					if arg:sub(2, 2) == first then
						if #arg == 2 then
							if self.options[arg] then
								local option = self:get_option(arg)
								self:invoke(option, arg)
							else
								self:close()
							end

							self.handle_options = false
						else
							local equals = arg:find("=")
							if equals then
								local name = arg:sub(1, equals - 1)
								local option = self:get_option(name)

								if option.element._maxargs <= 0 then
									self:error("option '%s' does not take arguments", name)
								end

								self:invoke(option, name)
								self:pass(arg:sub(equals + 1))
							else
								local option = self:get_option(arg)
								self:invoke(option, arg)
							end
						end
					else
						for i = 2, #arg do
							local name = first .. arg:sub(i, i)
							local option = self:get_option(name)
							self:invoke(option, name)

							if i ~= #arg and option.element._maxargs > 0 then
								self:pass(arg:sub(i + 1))
								break
							end
						end
					end
				end
			end
		end

		if plain then
			self:pass(arg)
		end
	end

	self:finalize()
	return self.result
end

function Parser:error(msg)
	stdio.ewrite(("%s\n\nError: %s\n"):format(self:get_usage(), msg))
	process.exit(1)
end

-- Compatibility with strict.lua and other checkers:
local default_cmdline = require("@lune/process").args

function Parser:_parse(args, error_handler)
	return ParseState(self, error_handler):parse(args or default_cmdline)
end

function Parser:parse(args)
	return self:_parse(args, self.error)
end

local function xpcall_error_handler(err)
	return tostring(err) .. "\noriginal " .. debug.traceback("", 2):sub(2)
end

function Parser:pparse(args)
	local parse_error

	local ok, result = xpcall(function()
		return self:_parse(args, function(_, err)
			parse_error = err
			error(err, 0)
		end)
	end, xpcall_error_handler)

	if ok then
		return true, result
	elseif not parse_error then
		error(result, 0)
	else
		return false, parse_error
	end
end

local argparse = {}

argparse.version = "0.6.0"

setmetatable(argparse, {
	__call = function(_, ...)
		return Parser(default_cmdline[0]):add_help(true)(...)
	end,
})


















































































































































return (argparse :: any) :: typeof(setmetatable(
	{} :: {
		version: string,
	},
	{} :: {
		__call: (
			self: any,
			name: string?,
			description: string?,
			epilog: string?
		) -> typeof(setmetatable(
			{} :: Parser__DARKLUA_TYPE_B,
			{} :: {
				__call: (
					self: any,
					{
						name: string?,
						description: string?,
						epilog: string?,
					}
				) -> Parser__DARKLUA_TYPE_B,
			}
		)),
	}
))
end function __DARKLUA_BUNDLE_MODULES.a():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.a()
return module end function __DARKLUA_BUNDLE_MODULES.b():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.b if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.b=v end return v.c end end do local function __modImpl()


return nil
end function __DARKLUA_BUNDLE_MODULES.c():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.c if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.c=v end return v.c end end do local function __modImpl()
local function all<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if not predicate(element, index) then
            return false
        end
    end
    return true
end

return all
end function __DARKLUA_BUNDLE_MODULES.d():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.d if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.d=v end return v.c end end do local function __modImpl()
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











return (reduce :: any) :: reduceFromFirstValue__DARKLUA_TYPE_D & reduceWithAccumulator__DARKLUA_TYPE_E
end function __DARKLUA_BUNDLE_MODULES.e():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.e if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.e=v end return v.c end end do local function __modImpl()
local reduce = __DARKLUA_BUNDLE_MODULES.e()

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






return (alternate :: any) :: alternate1__DARKLUA_TYPE_F & alternate2__DARKLUA_TYPE_G & alternate3__DARKLUA_TYPE_H & alternateAll__DARKLUA_TYPE_I
end function __DARKLUA_BUNDLE_MODULES.f():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.f if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.f=v end return v.c end end do local function __modImpl()
local function any<T>(array: { T }, predicate: (element: T, index: number) -> boolean): boolean
    for index, element in array do
        if predicate(element, index) then
            return true
        end
    end
    return false
end

return any
end function __DARKLUA_BUNDLE_MODULES.g():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.g if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.g=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.h():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.h if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.h=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.i():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.i if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.i=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.j():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.j if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.j=v end return v.c end end do local function __modImpl()
local function contains<T>(array: { T }, element: T): boolean
    for _, value in array do
        if value == element then
            return true
        end
    end
    return false
end

return contains
end function __DARKLUA_BUNDLE_MODULES.k():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.k if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.k=v end return v.c end end do local function __modImpl()
return table.clone
end function __DARKLUA_BUNDLE_MODULES.l():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.l if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.l=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.m():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.m if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.m=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.n():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.n if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.n=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.o():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.o if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.o=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.p():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.p if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.p=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.q=v end return v.c end end do local function __modImpl()
local function findIndexByValue<T>(array: { T }, element: T, start: number?): number?
    return table.find(array, element, start)
end

return findIndexByValue
end function __DARKLUA_BUNDLE_MODULES.r():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.r if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.r=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.s():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.s if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.s=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.t():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.t if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.t=v end return v.c end end do local function __modImpl()
local isArray = __DARKLUA_BUNDLE_MODULES.t()

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
end function __DARKLUA_BUNDLE_MODULES.u():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.u if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.u=v end return v.c end end do local function __modImpl()
local isArray = __DARKLUA_BUNDLE_MODULES.t()

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
end function __DARKLUA_BUNDLE_MODULES.v():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.v if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.v=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.w():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.w if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.w=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.x():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.x if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.x=v end return v.c end end do local function __modImpl()
local function isEmpty(value: { [any]: any }): boolean
    return next(value) == nil
end

return isEmpty
end function __DARKLUA_BUNDLE_MODULES.y():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.y if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.y=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.z():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.z if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.z=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.A():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.A if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.A=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.B():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.B if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.B=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.C():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.C if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.C=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.D():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.D if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.D=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.E():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.E if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.E=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.F():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.F if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.F=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.G():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.G if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.G=v end return v.c end end do local function __modImpl()
local function product(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 1 else initialValue

    for _, element in array do
        result *= element
    end

    return result
end

return product
end function __DARKLUA_BUNDLE_MODULES.H():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.H if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.H=v end return v.c end end do local function __modImpl()
local function productBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    local result = if initialValue == nil then 1 else initialValue

    for _, element in array do
        result *= map(element)
    end

    return result
end

return productBy
end function __DARKLUA_BUNDLE_MODULES.I():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.I if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.I=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.J():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.J if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.J=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.K():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.K if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.K=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.L():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.L if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.L=v end return v.c end end do local function __modImpl()
local function sort<T>(array: { T }, comparator: ((T, T) -> boolean)?): { T }
    if #array <= 1 then
        return array
    end
    local result = table.clone(array)
    table.sort(result, comparator)
    return result
end

return sort
end function __DARKLUA_BUNDLE_MODULES.M():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.M if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.M=v end return v.c end end do local function __modImpl()
local removeSortedIndexes = __DARKLUA_BUNDLE_MODULES.L()
local sort = __DARKLUA_BUNDLE_MODULES.M()

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
end function __DARKLUA_BUNDLE_MODULES.N():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.N if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.N=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.O():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.O if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.O=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.P():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.P if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.P=v end return v.c end end do local function __modImpl()
local map = __DARKLUA_BUNDLE_MODULES.z()



local function sortByKey<T, Comparable>(array: { T }, key: (T) -> Comparable): { T }
    if #array <= 1 then
        return array
    end
    local result: { KeyElement__DARKLUA_TYPE_J<Comparable, T> } = map(array, function(element)
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
end function __DARKLUA_BUNDLE_MODULES.Q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Q=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.R():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.R if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.R=v end return v.c end end do local function __modImpl()
local function sum(array: { number }, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += element
    end

    return result
end

return sum
end function __DARKLUA_BUNDLE_MODULES.S():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.S if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.S=v end return v.c end end do local function __modImpl()
local function sumBy<T>(array: { T }, map: (T) -> number, initialValue: number?): number
    local result = if initialValue == nil then 0 else initialValue

    for _, element in array do
        result += map(element)
    end

    return result
end

return sumBy
end function __DARKLUA_BUNDLE_MODULES.T():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.T if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.T=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.U():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.U if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.U=v end return v.c end end do local function __modImpl()
local reduce = __DARKLUA_BUNDLE_MODULES.e()

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






return (zip :: any) :: zip1__DARKLUA_TYPE_K & zip2__DARKLUA_TYPE_L & zip3__DARKLUA_TYPE_M & zipAll__DARKLUA_TYPE_N
end function __DARKLUA_BUNDLE_MODULES.V():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.V if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.V=v end return v.c end end do local function __modImpl()
return table.clone
end function __DARKLUA_BUNDLE_MODULES.W():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.W if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.W=v end return v.c end end do local function __modImpl()
local function count<K, V>(map: { [K]: V }): number
    local length = 0
    for _ in map do
        length += 1
    end
    return length
end

return count
end function __DARKLUA_BUNDLE_MODULES.X():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.X if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.X=v end return v.c end end do local function __modImpl()
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





return entries :: EntriesFn__DARKLUA_TYPE_O
end function __DARKLUA_BUNDLE_MODULES.Y():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Y if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Y=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.Z():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Z if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Z=v end return v.c end end do local function __modImpl()
local function isEmpty(value: { [any]: any }): boolean
    return next(value) == nil
end

return isEmpty
end function __DARKLUA_BUNDLE_MODULES._():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache._ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache._=v end return v.c end end do local function __modImpl()
local function keys<K, V>(map: { [K]: V }): { K }
    local result = {}
    for key in map do
        table.insert(result, key)
    end
    return result
end

return keys
end function __DARKLUA_BUNDLE_MODULES.aa():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aa if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aa=v end return v.c end end do local function __modImpl()
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
end function __DARKLUA_BUNDLE_MODULES.ab():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ab if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ab=v end return v.c end end do local function __modImpl()
local None = table.freeze(setmetatable({}, {
    __index = function()
        error('attempt to index on None symbol')
    end,
    __tostring = function()
        return '<None>'
    end,
}))

return None
end function __DARKLUA_BUNDLE_MODULES.ac():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ac if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ac=v end return v.c end end do local function __modImpl()
local None = __DARKLUA_BUNDLE_MODULES.ac()

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
end function __DARKLUA_BUNDLE_MODULES.ad():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ad if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ad=v end return v.c end end do local function __modImpl()
local None = __DARKLUA_BUNDLE_MODULES.ac()

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








return (merge :: any) :: merge1__DARKLUA_TYPE_P & merge2__DARKLUA_TYPE_Q & merge3__DARKLUA_TYPE_R & merge4__DARKLUA_TYPE_S & merge5__DARKLUA_TYPE_T & mergeAll__DARKLUA_TYPE_U
end function __DARKLUA_BUNDLE_MODULES.ae():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ae if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ae=v end return v.c end end do local function __modImpl()
local isEmpty = __DARKLUA_BUNDLE_MODULES._()

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
end function __DARKLUA_BUNDLE_MODULES.af():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.af if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.af=v end return v.c end end do local function __modImpl()
local function values<K, V>(map: { [K]: V }): { V }
    local result = {}
    for _, value in map do
        table.insert(result, value)
    end
    return result
end

return values
end function __DARKLUA_BUNDLE_MODULES.ag():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ag if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ag=v end return v.c end end do local function __modImpl()
local type = __DARKLUA_BUNDLE_MODULES.c()



local function fromArray<T>(array: { T }): Set__DARKLUA_TYPE_V<T>
    local set: Set__DARKLUA_TYPE_V<T> = {}
    for _, element in array do
        set[element] = true
    end
    return set
end

return fromArray
end function __DARKLUA_BUNDLE_MODULES.ah():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ah if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ah=v end return v.c end end do local function __modImpl()
local WEAK_KEYS_METATABLE = { __mode = 'k' }

local function WeakMap<K, V>(default: { [K]: V }?): { [K]: V }
    local value = default or {}
    return setmetatable(value :: any, WEAK_KEYS_METATABLE) :: any
end

return WeakMap
end function __DARKLUA_BUNDLE_MODULES.ai():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ai if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ai=v end return v.c end end do local function __modImpl()
local setType = __DARKLUA_BUNDLE_MODULES.c()



local Disk = {
    Array = {
        all = __DARKLUA_BUNDLE_MODULES.d(),
        alternate = __DARKLUA_BUNDLE_MODULES.f(),
        any = __DARKLUA_BUNDLE_MODULES.g(),
        average = __DARKLUA_BUNDLE_MODULES.h(),
        averageBy = __DARKLUA_BUNDLE_MODULES.i(),
        concat = __DARKLUA_BUNDLE_MODULES.j(),
        contains = __DARKLUA_BUNDLE_MODULES.k(),
        copy = __DARKLUA_BUNDLE_MODULES.l(),
        deduplicate = __DARKLUA_BUNDLE_MODULES.m(),
        deduplicateByKey = __DARKLUA_BUNDLE_MODULES.n(),
        filter = __DARKLUA_BUNDLE_MODULES.o(),
        find = __DARKLUA_BUNDLE_MODULES.p(),
        findIndex = __DARKLUA_BUNDLE_MODULES.q(),
        findIndexByValue = __DARKLUA_BUNDLE_MODULES.r(),
        findMap = __DARKLUA_BUNDLE_MODULES.s(),
        flatMap = __DARKLUA_BUNDLE_MODULES.u(),
        flatten = __DARKLUA_BUNDLE_MODULES.v(),
        fromFn = __DARKLUA_BUNDLE_MODULES.w(),
        fromTryFn = __DARKLUA_BUNDLE_MODULES.x(),
        isArray = __DARKLUA_BUNDLE_MODULES.t()
,
        isEmpty = __DARKLUA_BUNDLE_MODULES.y(),
        map = __DARKLUA_BUNDLE_MODULES.z(),
        maximum = __DARKLUA_BUNDLE_MODULES.A(),
        maximumBy = __DARKLUA_BUNDLE_MODULES.B(),
        minimum = __DARKLUA_BUNDLE_MODULES.C(),
        minimumBy = __DARKLUA_BUNDLE_MODULES.D(),
        partition = __DARKLUA_BUNDLE_MODULES.E(),
        pop = __DARKLUA_BUNDLE_MODULES.F(),
        popFirst = __DARKLUA_BUNDLE_MODULES.G(),
        product = __DARKLUA_BUNDLE_MODULES.H(),
        productBy = __DARKLUA_BUNDLE_MODULES.I(),
        push = __DARKLUA_BUNDLE_MODULES.J(),
        range = __DARKLUA_BUNDLE_MODULES.K(),
        reduce = __DARKLUA_BUNDLE_MODULES.e()
,
        removeIndexes = __DARKLUA_BUNDLE_MODULES.N(),
        removeSortedIndexes = __DARKLUA_BUNDLE_MODULES.L()
,
        removeValues = __DARKLUA_BUNDLE_MODULES.O(),
        reverse = __DARKLUA_BUNDLE_MODULES.P(),
        reversed = __DARKLUA_BUNDLE_MODULES.P(),
        sort = __DARKLUA_BUNDLE_MODULES.M()
,
        sortByKey = __DARKLUA_BUNDLE_MODULES.Q(),
        stepBy = __DARKLUA_BUNDLE_MODULES.R(),
        sum = __DARKLUA_BUNDLE_MODULES.S(),
        sumBy = __DARKLUA_BUNDLE_MODULES.T(),
        takeWhile = __DARKLUA_BUNDLE_MODULES.U(),
        zip = __DARKLUA_BUNDLE_MODULES.V(),
    },
    Map = {
        copy = __DARKLUA_BUNDLE_MODULES.W(),
        count = __DARKLUA_BUNDLE_MODULES.X(),
        entries = __DARKLUA_BUNDLE_MODULES.Y(),
        invert = __DARKLUA_BUNDLE_MODULES.Z(),
        isEmpty = __DARKLUA_BUNDLE_MODULES._(),
        keys = __DARKLUA_BUNDLE_MODULES.aa(),
        mapEntries = __DARKLUA_BUNDLE_MODULES.ab(),
        mapValues = __DARKLUA_BUNDLE_MODULES.ad(),
        merge = __DARKLUA_BUNDLE_MODULES.ae(),
        remove = __DARKLUA_BUNDLE_MODULES.af(),
        values = __DARKLUA_BUNDLE_MODULES.ag(),
    },
    Set = {
        fromArray = __DARKLUA_BUNDLE_MODULES.ah(),
    },
    None = __DARKLUA_BUNDLE_MODULES.ac()
,
    WeakMap = __DARKLUA_BUNDLE_MODULES.ai(),
}

return Disk
end function __DARKLUA_BUNDLE_MODULES.aj():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aj if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aj=v end return v.c end end do local function __modImpl()local module = __DARKLUA_BUNDLE_MODULES.aj()
return module end function __DARKLUA_BUNDLE_MODULES.ak():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ak if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ak=v end return v.c end end do local function __modImpl()
























local Prefix: PrefixStatic__DARKLUA_TYPE__ = {} :: any
local PrefixMetatable = {
    __index = Prefix,
    __eq = function(self: Prefix__DARKLUA_TYPE_Z, other: Prefix__DARKLUA_TYPE_Z): boolean
        return self:equal(other)
    end,
}

local function new(self: PrefixEnum__DARKLUA_TYPE_Y)
    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix.Verbatim(value: string): Prefix__DARKLUA_TYPE_Z
    return new({ type = 'Verbatim', value = value })
end

function Prefix.VerbatimUNC(hostName: string, shareName: string): Prefix__DARKLUA_TYPE_Z
    return new({ type = 'VerbatimUNC', hostName = hostName, shareName = shareName })
end

function Prefix.VerbatimDisk(value: string): Prefix__DARKLUA_TYPE_Z
    return new({ type = 'VerbatimDisk', value = value })
end

function Prefix.DeviceNS(value: string): Prefix__DARKLUA_TYPE_Z
    return new({ type = 'DeviceNS', value = value })
end

function Prefix.UNC(hostName: string, shareName: string): Prefix__DARKLUA_TYPE_Z
    return new({ type = 'UNC', hostName = hostName, shareName = shareName })
end

function Prefix.Disk(value: string): Prefix__DARKLUA_TYPE_Z
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

function Prefix:clone(): Prefix__DARKLUA_TYPE_Z
    local self = table.clone(self)

    return setmetatable(self, PrefixMetatable) :: any
end

function Prefix:equal(other: Prefix__DARKLUA_TYPE_Z): boolean
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
end function __DARKLUA_BUNDLE_MODULES.al():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.al if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.al=v end return v.c end end do local function __modImpl()

















local PrefixParserSlice: PrefixParserSliceStatic__DARKLUA_TYPE_3 = {} :: any
local PrefixParserSliceMetatable = {
    __index = PrefixParserSlice,
}

function PrefixParserSlice.new(path: string, prefix: string): PrefixParserSlice__DARKLUA_TYPE_0
    local self: Private__DARKLUA_TYPE_1 = {
        _path = path,
        _prefix = prefix,
        _index = 1,
    }

    return setmetatable(self, PrefixParserSliceMetatable) :: any
end

function PrefixParserSlice:stripPrefix(prefix: string): PrefixParserSlice__DARKLUA_TYPE_0?
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_2 = self :: any

    local prefixLength = #prefix
    if string.sub(self._prefix, self._index, self._index + prefixLength - 1) == prefix then
        local self: Private__DARKLUA_TYPE_1 = {
            _path = self._path,
            _prefix = self._prefix,
            _index = self._index + prefixLength,
        }

        return setmetatable(self, PrefixParserSliceMetatable) :: any
    end
    return nil
end

function PrefixParserSlice:prefixBytes(): string
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_2 = self :: any

    return string.sub(self._path, 1, self._index)
end

function PrefixParserSlice:finish(): string
    local self: PrivatePrefixParserSlice__DARKLUA_TYPE_2 = self :: any

    return string.sub(self._path, self._index)
end

return PrefixParserSlice
end function __DARKLUA_BUNDLE_MODULES.am():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.am if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.am=v end return v.c end end do local function __modImpl()
local PrefixParserSlice = __DARKLUA_BUNDLE_MODULES.am()



















local PrefixParser: PrefixParserStatic__DARKLUA_TYPE_8 = {} :: any
local PrefixParserMetatable = {
    __index = PrefixParser,
}

function PrefixParser.new(path: string, length: number): PrefixParser__DARKLUA_TYPE_5
    local self: Private__DARKLUA_TYPE_6 = {
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

function PrefixParser:asSlice(): PrefixParserSlice__DARKLUA_TYPE_4
    local self: PrivatePrefixParser__DARKLUA_TYPE_7 = self :: any

    return PrefixParserSlice.new(self._path, string.sub(self._prefix, 1, math.min(#self._path, 8)))
end

return PrefixParser
end function __DARKLUA_BUNDLE_MODULES.an():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.an if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.an=v end return v.c end end do local function __modImpl()-- https://github.com/rust-lang/rust/blob/master/library/std/src/sys/path/windows.rs


local Prefix = __DARKLUA_BUNDLE_MODULES.al()
local PrefixParser = __DARKLUA_BUNDLE_MODULES.an()




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

local function parsePrefix(path: string): Prefix__DARKLUA_TYPE_9?
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
end function __DARKLUA_BUNDLE_MODULES.ao():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ao if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ao=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.al()
local parsePrefixWindows = __DARKLUA_BUNDLE_MODULES.ao()



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

local function parsePrefixUnix(_path: string): Prefix__DARKLUA_TYPE_ab?
    return nil
end

local parsePrefix: (path: string) -> Prefix__DARKLUA_TYPE_ab? = if IS_WINDOWS
    then parsePrefixWindows
    else parsePrefixUnix

return {
    MAIN_SEPARATOR_STR = MAIN_SEPARATOR_STR,
    isSepByte = isSepByte,
    isVerbatimSep = isVerbatimSep,
    parsePrefix = parsePrefix,
}
end function __DARKLUA_BUNDLE_MODULES.ap():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ap if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ap=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.al()
local sysPath = __DARKLUA_BUNDLE_MODULES.ap()

local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR
































local Component: ComponentStatic__DARKLUA_TYPE_ai = {} :: any
local ComponentMetatable = {
    __index = Component,
    __tostring = function(self)
        return self:toString()
    end,
    __eq = function(self: Prefix__DARKLUA_TYPE_ac, other: Prefix__DARKLUA_TYPE_ac): boolean
        return self:equal(other)
    end,
}

function Component.normal(value: string): Component__DARKLUA_TYPE_ah
    local self: ComponentEnum__DARKLUA_TYPE_af = { type = 'normal', value = value }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.rootDir(): Component__DARKLUA_TYPE_ah
    local self: ComponentEnum__DARKLUA_TYPE_af = { type = 'rootDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.curDir(): Component__DARKLUA_TYPE_ah
    local self: ComponentEnum__DARKLUA_TYPE_af = { type = 'curDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.parentDir(): Component__DARKLUA_TYPE_ah
    local self: ComponentEnum__DARKLUA_TYPE_af = { type = 'parentDir' }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component.prefix(raw: string, prefix: Prefix__DARKLUA_TYPE_ac): Component__DARKLUA_TYPE_ah
    local self: PrefixComponent__DARKLUA_TYPE_ad = { type = 'prefix', raw = raw, parsed = prefix }

    return setmetatable(self, ComponentMetatable) :: any
end

function Component:toString(): string
    local componentType = self.type
    return if componentType == 'normal'
        then (self :: NormalComponent__DARKLUA_TYPE_ae & ComponentCommon__DARKLUA_TYPE_ag).value
        elseif componentType == 'curDir' then '.'
        elseif componentType == 'parentDir' then '..'
        elseif componentType == 'rootDir' then MAIN_SEPARATOR_STR
        else (self :: PrefixComponent__DARKLUA_TYPE_ad & ComponentCommon__DARKLUA_TYPE_ag).raw
end

function Component:equal(other: Component__DARKLUA_TYPE_ah): boolean
    local selfType = self.type

    if selfType ~= other.type then
        return false
    end

    if selfType == 'normal' then
        return (self :: NormalComponent__DARKLUA_TYPE_ae & ComponentCommon__DARKLUA_TYPE_ag).value
            == (other :: NormalComponent__DARKLUA_TYPE_ae & ComponentCommon__DARKLUA_TYPE_ag).value
    elseif selfType == 'prefix' then
        return (self :: PrefixComponent__DARKLUA_TYPE_ad & ComponentCommon__DARKLUA_TYPE_ag).parsed:equal(
            (other :: PrefixComponent__DARKLUA_TYPE_ad & ComponentCommon__DARKLUA_TYPE_ag).parsed
        )
    end

    return true
end

return Component
end function __DARKLUA_BUNDLE_MODULES.aq():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aq if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aq=v end return v.c end end do local function __modImpl()
local Disk = __DARKLUA_BUNDLE_MODULES.ak()

local Array = Disk.Array



































local Rev: RevStatic__DARKLUA_TYPE_an = {} :: any
local RevMetatable = {
    __index = Rev,
    __iter = function<T>(self: PrivateRev__DARKLUA_TYPE_am<T>)
        local items = self:collect()
        return next, items
    end,
}

function Rev.new<T>(iter: DoubleEndedIterator__DARKLUA_TYPE_ak<T>): Rev__DARKLUA_TYPE_aj<T>
    local self: Private__DARKLUA_TYPE_al<T> = {
        _iter = iter,
    }

    return setmetatable(self, RevMetatable) :: any
end

function Rev:next<T>(): T?
    local self: PrivateRev__DARKLUA_TYPE_am<T> = self :: any

    return self._iter:nextBack()
end

function Rev:collect<T>(): { T }
    local self: PrivateRev__DARKLUA_TYPE_am<T> = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Rev:nextBack<T>(): T?
    local self: PrivateRev__DARKLUA_TYPE_am<T> = self :: any

    return self._iter:next()
end

function Rev:clone<T>(): Rev__DARKLUA_TYPE_aj<T>
    local self: PrivateRev__DARKLUA_TYPE_am<T> = self :: any

    return Rev.new(self._iter:clone())
end

return Rev
end function __DARKLUA_BUNDLE_MODULES.ar():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ar if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ar=v end return v.c end end do local function __modImpl()
local Disk = __DARKLUA_BUNDLE_MODULES.ak()

local Component = __DARKLUA_BUNDLE_MODULES.aq()
local Prefix = __DARKLUA_BUNDLE_MODULES.al()
local Rev = __DARKLUA_BUNDLE_MODULES.ar()
local sysPath = __DARKLUA_BUNDLE_MODULES.ap()

local isSepByte = sysPath.isSepByte
local isVerbatimSep = sysPath.isVerbatimSep





local Array = Disk.Array










































local function getStateValue(state: State__DARKLUA_TYPE_au)
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






















local Components: ComponentsStatic__DARKLUA_TYPE_ax = {} :: any
local ComponentsMetatable = {
    __index = Components,
    __iter = function(self: PrivateComponents__DARKLUA_TYPE_aw)
        local items = self:collect()
        return next, items
    end,
}

function Components.new(path: string, prefix: Prefix__DARKLUA_TYPE_ap?, hasPhysicalRoot: boolean): Components__DARKLUA_TYPE_as
    local self: Private__DARKLUA_TYPE_av = {
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
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local prefix = self.prefix
    return if prefix then prefix:len() else 0
end

function Components:prefixVerbatim(): boolean
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local prefix = self.prefix
    return if prefix then prefix:isVerbatim() else false
end

-- how much of the prefix is left from the point of view of iteration?
function Components:prefixRemaining(): number
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local front = self._front
    return if front == 'Prefix' then self:prefixLen() else 0
end

-- Given the iteration so far, how much of the pre-State::Body path is left?
function Components:lenBeforeBody(): number
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local front: State__DARKLUA_TYPE_au = self._front
    local isBeforeStartDir = getStateValue(front) <= getStateValue('StartDir')
    local root = if isBeforeStartDir and self._hasPhysicalRoot then 1 else 0
    local curDir = if isBeforeStartDir and self:includeCurDir() then 1 else 0

    return self:prefixRemaining() + root + curDir
end

-- is the iteration complete?
function Components:finished(): boolean
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local front: State__DARKLUA_TYPE_au = self._front
    local back: State__DARKLUA_TYPE_au = self._back
    return front == 'Done' or back == 'Done' or getStateValue(front) > getStateValue(back)
end

function Components:isSepByte(b: char__DARKLUA_TYPE_ar): boolean
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    return if self:prefixVerbatim() then isVerbatimSep(b) else isSepByte(b)
end

function Components:asPathString(): string
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local comps: PrivateComponents__DARKLUA_TYPE_aw = self:clone() :: any
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
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
function Components:parseSingleComponent(comp: string): Component__DARKLUA_TYPE_ao?
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
function Components:parseNextComponent(): (number, Component__DARKLUA_TYPE_ao?)
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
function Components:parseNextComponentBack(): (number, Component__DARKLUA_TYPE_ao?)
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

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
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    while #self._path > self:lenBeforeBody() do
        local size, comp = self:parseNextComponentBack()
        if comp ~= nil then
            return
        else
            self._path = string.sub(self._path, 1, #self._path - size)
        end
    end
end

function Components:next(): Component__DARKLUA_TYPE_ao?
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    while not self:finished() do
        local front: State__DARKLUA_TYPE_au = self._front

        if front == 'Prefix' then
            self._front = 'StartDir'
            local prefixLen = self:prefixLen()
            if prefixLen > 0 then
                local raw = string.sub(self._path, 1, prefixLen)
                self._path = string.sub(self._path, prefixLen + 1)

                return Component.prefix(raw, self.prefix :: Prefix__DARKLUA_TYPE_ap)
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

function Components:collect(): { Component__DARKLUA_TYPE_ao }
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

function Components:rev(): Rev__DARKLUA_TYPE_aq<Component__DARKLUA_TYPE_ao>
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    return Rev.new(self:clone())
end

function Components:nextBack(): Component__DARKLUA_TYPE_ao?
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    while not self:finished() do
        local back: State__DARKLUA_TYPE_au = self._back

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
                return Component.prefix(self._path, self.prefix :: Prefix__DARKLUA_TYPE_ap)
            end
        else
            error('unreachable')
        end
    end

    return nil
end

function Components:clone(): Components__DARKLUA_TYPE_as
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any

    local newSelf: PrivateComponents__DARKLUA_TYPE_aw = table.clone(self) :: any

    if newSelf.prefix then
        newSelf.prefix = newSelf.prefix:clone()
    end

    return setmetatable(newSelf, ComponentsMetatable) :: any
end

function Components:equal(other: Components__DARKLUA_TYPE_as): boolean
    local self: PrivateComponents__DARKLUA_TYPE_aw = self :: any
    local other: PrivateComponents__DARKLUA_TYPE_aw = other :: any

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
end function __DARKLUA_BUNDLE_MODULES.as():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.as if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.as=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.aq()






local function iterAfter<T>(
    iter: T & ComponentIterator__DARKLUA_TYPE_az & Clone__DARKLUA_TYPE_aA<ComponentIterator__DARKLUA_TYPE_az>,
    prefix: T & ComponentIterator__DARKLUA_TYPE_az
): (T & ComponentIterator__DARKLUA_TYPE_az)?
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
end function __DARKLUA_BUNDLE_MODULES.at():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.at if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.at=v end return v.c end end do local function __modImpl()-- implementation based on Rust path library
-- https://github.com/rust-lang/rust/blob/bd7d328807a8bb15732ebb764e1ea3df4fbe3fd1/library/std/src/path.rs

local Disk = __DARKLUA_BUNDLE_MODULES.ak()

local Component = __DARKLUA_BUNDLE_MODULES.aq()
local Components = __DARKLUA_BUNDLE_MODULES.as()
local Prefix = __DARKLUA_BUNDLE_MODULES.al()
local iterAfter = __DARKLUA_BUNDLE_MODULES.at()
local sysPath = __DARKLUA_BUNDLE_MODULES.ap()

local Array = Disk.Array

local isSepByte = sysPath.isSepByte
local parsePrefix = sysPath.parsePrefix
local MAIN_SEPARATOR_STR = sysPath.MAIN_SEPARATOR_STR

local IS_WINDOWS = MAIN_SEPARATOR_STR == '\\'





local function hasRedoxScheme(_s: string): boolean
    return false
end
















local Ancestors: AncestorsStatic__DARKLUA_TYPE_aH = {} :: any
local AncestorsMetatable = {
    __index = Ancestors,
}

local function newAncestors(path: Path__DARKLUA_TYPE_aJ?): Ancestors__DARKLUA_TYPE_aE
    local self: AncestorsPrivate__DARKLUA_TYPE_aF = {
        _next = path,
    }

    return setmetatable(self, AncestorsMetatable) :: any
end

function Ancestors:next(): Path__DARKLUA_TYPE_aJ?
    local self: PrivateAncestors__DARKLUA_TYPE_aG = self :: any

    local next = self._next
    self._next = next and next:parent()

    return next
end

function Ancestors:collect(): { Path__DARKLUA_TYPE_aJ }
    local self: PrivateAncestors__DARKLUA_TYPE_aG = self :: any

    return Array.fromFn(function()
        return self:next()
    end)
end

















































local Path: PathStatic__DARKLUA_TYPE_aM = {} :: any
local PathMetatable = {
    __index = Path,
    __tostring = function(self: Path__DARKLUA_TYPE_aJ): string
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
local function hasPhysicalRoot(s: string, prefix: Prefix__DARKLUA_TYPE_aD?): boolean
    local path = if prefix ~= nil then string.sub(s, prefix:len() + 1) else s
    return path ~= '' and isSepByte(string.sub(path, 1, 1))
end

function Path.new(path: string): Path__DARKLUA_TYPE_aJ
    local self: Private__DARKLUA_TYPE_aK = {
        _inner = path,

        _prefix = nil :: any,
    }

    return setmetatable(self, PathMetatable) :: any
end

function Path.from(path: AsPath__DARKLUA_TYPE_aI): Path__DARKLUA_TYPE_aJ
    local pathType = type(path)
    if pathType == 'string' then
        return Path.new(path :: string)
    elseif Path.is(path) then
        return path :: Path__DARKLUA_TYPE_aJ
    elseif Components.is(path) then
        return Path.new(path:asPathString())
    end

    error('unable to create path from value')
end

function Path.is(value: unknown): boolean
    return type(value) == 'table' and getmetatable(value :: any) == PathMetatable
end

function Path:toString(): string
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    return self._inner
end

function Path:toPathBuf(): Path__DARKLUA_TYPE_aJ
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    return setmetatable(table.clone(self), PathMetatable) :: any
end

function Path:isAbsolute(): boolean
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

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
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    return self:components():hasRoot()
end

function Path:parent(): Path__DARKLUA_TYPE_aJ?
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
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

function Path:ancestors(): Ancestors__DARKLUA_TYPE_aE
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    return newAncestors(self)
end

function Path:fileName(): string?
    local components = self:components()
    local p = components:nextBack()

    return if p and p.type == 'normal' then (p :: any).value else nil
end

function Path:stripPrefix(base: AsPath__DARKLUA_TYPE_aI): Path__DARKLUA_TYPE_aJ?
    local result: Components__DARKLUA_TYPE_aC? = iterAfter(self:components(), Path.from(base):components())

    return result and Path.from(result:asPathString())
end

function Path:startsWith(base: AsPath__DARKLUA_TYPE_aI): boolean
    return iterAfter(self:components(), Path.from(base):components()) ~= nil
end

function Path:endsWith(child: AsPath__DARKLUA_TYPE_aI): boolean
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

function Path:join(path: AsPath__DARKLUA_TYPE_aI): Path__DARKLUA_TYPE_aJ
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    local buf = self:toPathBuf()
    buf:push(path)
    return buf
end

function Path:withFileName(fileName: string): Path__DARKLUA_TYPE_aJ
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    local buf = self:toPathBuf()
    buf:setFileName(fileName)
    return buf
end

function Path:withExtension(extension: string): Path__DARKLUA_TYPE_aJ
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    local buf = self:toPathBuf()
    buf:setExtension(extension)
    return buf
end

function Path:components(): Components__DARKLUA_TYPE_aC
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    local prefix = parsePrefix(self._inner)
    return Components.new(
        self._inner,
        prefix,
        hasPhysicalRoot(self._inner, prefix) or hasRedoxScheme(self._inner)
    )
end

function Path:equal(other: Path__DARKLUA_TYPE_aJ): boolean
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    return self:components():equal(other:components())
end

function Path:push(path: AsPath__DARKLUA_TYPE_aI): ()
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    local path = Path.from(path) :: PrivatePath__DARKLUA_TYPE_aL

    -- in general, a separator is needed if the rightmost byte is not a separator
    local needSep = if self._inner == ''
        then false
        else not isSepByte(string.sub(self._inner, -1, -1))

    -- in the special case of `C:` on Windows, do *not* add a separator
    local comps = self:components()

    if
        comps:prefixLen() > 0
        and comps:prefixLen() == #(comps :: any)._path
        and (comps.prefix :: Prefix__DARKLUA_TYPE_aD):isDrive()
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

        for _, c: Component__DARKLUA_TYPE_aB in buf :: { any } do
            if needSep and c.type ~= 'rootDir' then
                table.insert(res, MAIN_SEPARATOR_STR)
            end
            table.insert(res, c:toString())

            local prefix: Prefix__DARKLUA_TYPE_aD = (c :: any).parsed
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
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    local parent = self:parent() :: PrivatePath__DARKLUA_TYPE_aL?
    if parent ~= nil then
        self._inner = parent._inner
        return true
    else
        return false
    end
end

function Path:setFileName(fileName: string)
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

    if self:fileName() ~= nil then
        self:pop()
    end
    self:push(fileName)
end

function Path:setExtension(extension: string): boolean
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any

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
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    self._inner = ''
end

function Path:_prefix(): Prefix__DARKLUA_TYPE_aD?
    local self: PrivatePath__DARKLUA_TYPE_aL = self :: any
    return self:components().prefix
end

return Path
end function __DARKLUA_BUNDLE_MODULES.au():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.au if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.au=v end return v.c end end do local function __modImpl()



























return nil
end function __DARKLUA_BUNDLE_MODULES.av():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.av if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.av=v end return v.c end end do local function __modImpl()
local Prefix = __DARKLUA_BUNDLE_MODULES.av()
































return nil
end function __DARKLUA_BUNDLE_MODULES.aw():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aw if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aw=v end return v.c end end do local function __modImpl()


































return nil
end function __DARKLUA_BUNDLE_MODULES.ax():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ax if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ax=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.aw()
local Prefix = __DARKLUA_BUNDLE_MODULES.av()
local Rev = __DARKLUA_BUNDLE_MODULES.ax()














































return nil
end function __DARKLUA_BUNDLE_MODULES.ay():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.ay if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.ay=v end return v.c end end do local function __modImpl()
local Component = __DARKLUA_BUNDLE_MODULES.aw()
local Components = __DARKLUA_BUNDLE_MODULES.ay()
local Prefix = __DARKLUA_BUNDLE_MODULES.av()














































return nil
end function __DARKLUA_BUNDLE_MODULES.az():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.az if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.az=v end return v.c end end do local function __modImpl()
local Path = __DARKLUA_BUNDLE_MODULES.az()
local Component = __DARKLUA_BUNDLE_MODULES.aw()





return nil
end function __DARKLUA_BUNDLE_MODULES.aA():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aA if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aA=v end return v.c end end do local function __modImpl()
local Path = __DARKLUA_BUNDLE_MODULES.au()
local types = __DARKLUA_BUNDLE_MODULES.aA()




return {
    Path = (Path :: any) :: {
		new: (path: string) -> Path__DARKLUA_TYPE_be,
		from: (path: AsPath__DARKLUA_TYPE_bf) -> Path__DARKLUA_TYPE_be,
		is: (value: unknown) -> boolean,
	},
}
end function __DARKLUA_BUNDLE_MODULES.aB():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aB if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aB=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aB()


return module end function __DARKLUA_BUNDLE_MODULES.aC():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aC if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aC=v end return v.c end end do local function __modImpl()
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






local function parseRange(rangeIn: RangeInput__DARKLUA_TYPE_bn): Range__DARKLUA_TYPE_bl
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

local function displayRange(range: Range__DARKLUA_TYPE_bl): string
	if not range.min and not range.max then
		return "[-inf, inf]"
	end

	local leftBracket = range.minExclusive and "(" or "["
	local rightBracket = range.maxExclusive and ")" or "]"
	return leftBracket .. (range.min or "") .. ", " .. (range.max or "") .. rightBracket
end

local function checkRange(value: number, range: Range__DARKLUA_TYPE_bl): boolean
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
	__tostring = function(self: Cause__DARKLUA_TYPE_bo)
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

local function causeFormatErr(self: Cause__DARKLUA_TYPE_bo)
	if self.ok then
		return "ok"
	else
		local type = self.encompassingType or self.errs[#self.errs].type

		return type:formatErr(self)
	end
end

function Cause.new(ok: boolean, errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_bo
	return setmetatable({ ok = ok, errs = errs, formatErr = causeFormatErr } :: Cause__DARKLUA_TYPE_bo, CauseMt) :: any
end

function Cause.ok(): Cause__DARKLUA_TYPE_bo
	return Cause.new(true, {})
end

function Cause.extendOk(cause: Cause__DARKLUA_TYPE_bo?): Cause__DARKLUA_TYPE_bo
	if not cause then
		return Cause.new(true, {})
	else
		return cause
	end
end

function Cause.err(type: any, input: any?, message: string?): Cause__DARKLUA_TYPE_bo
	return Cause.new(false, { { type = type, input = input, message = message } })
end

function Cause.extendErr(cause: Cause__DARKLUA_TYPE_bo?, type: any, input: any?, message: string?): Cause__DARKLUA_TYPE_bo
	if not cause then
		return Cause.new(false, { { type = type, input = input, message = message } })
	else
		table.insert(cause.errs, { type = type, input = input, message = message })
		return cause
	end
end

function Cause.errs(errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_bo
	return Cause.new(false, errs)
end

function Cause.extendErrs(cause: Cause__DARKLUA_TYPE_bo?, errs: { { type: any, input: any?, message: string? } }): Cause__DARKLUA_TYPE_bo
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
function Type.matches(self: Type__DARKLUA_TYPE_bt, ...: any): (boolean, Cause__DARKLUA_TYPE_bo)
	local cause = self._matches(...)
	cause.encompassingType = self
	return cause.ok, cause
end

--- Errors if the input does not match the type, otherwise returns the input.
function Type.assert<T...>(self: Type__DARKLUA_TYPE_bt, ...: T...): T...
local ok, cause = self:matches(...)
	if not ok then
		error(cause:formatErr())
	end
	return ...
end

--- Formats the type for display to the user.
function Type.format(self: Type__DARKLUA_TYPE_bt): string
	return self._format({}, SOFT_MAX_LINE_LENGTH, {})
end

--- Wraps a function with type asserts for its input args and returns.\
--- \
--- This implementation is not ergonomic, and is easily confused with GreenTea.wrapFn.
--- For this reason, Type.wrapFn will be removed in the next breaking release.\
--- @deprecated v0.4.11 -- use `GreenTea.wrapFn` instead
function Type.wrapFn<T>(self: Type__DARKLUA_TYPE_bt, fn: T): T
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

function Type.__call(self: Type__DARKLUA_TYPE_bt, ...: any): (boolean, string?)
	local ok, cause = self:matches(...)
	if ok then
		return true
	else
		return false, tostring(cause)
	end
end

function Type.__tostring(self: Type__DARKLUA_TYPE_bt): string
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
function Type.formatErr(self: Type__DARKLUA_TYPE_bt, cause: Cause__DARKLUA_TYPE_bo): string
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	local self: TypeRaw__DARKLUA_TYPE_bs
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
function GreenTea.coroutine(options: { status: CoroutineStatus__DARKLUA_TYPE_bu | { CoroutineStatus__DARKLUA_TYPE_bu } | nil }?): thread
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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

	local innerType: Type__DARKLUA_TYPE_bt? = if type ~= nil then GreenTea.typeof(type :: any) else nil

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	range: RangeInput__DARKLUA_TYPE_bn?,
	integer: boolean?,
	nan: boolean?,
}?): number
	local range = limits and limits.range and parseRange(limits.range)

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	bytes: RangeInput__DARKLUA_TYPE_bn?,
	graphemes: RangeInput__DARKLUA_TYPE_bn?,
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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
		length: RangeInput__DARKLUA_TYPE_bn?,
	}?
): ...T
	local lengthRange = options and options.length and parseRange(options.length)
	local varargType: Type__DARKLUA_TYPE_bt = GreenTea.typeof(type :: any)

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	return setmetatable(self :: TypeRaw__DARKLUA_TYPE_bs, Type) :: any
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
			local value: Type__DARKLUA_TYPE_bt = value
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
	local contents: { Type__DARKLUA_TYPE_bt } = contents :: any

	local vararg: Type__DARKLUA_TYPE_bt?
	if contents[#contents] and contents[#contents].kind == "vararg" then
		vararg = contents[#contents]
		contents[#contents] = nil
	end

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	

local args: Type__DARKLUA_TYPE_bt = args :: any
	-- selene: allow(shadowing)
	local returns: Type__DARKLUA_TYPE_bt = returns :: any

	assert(GreenTea.isGtType(args), "args must be a GreenTea type. Use GreenTea.args to specify args.")
	assert(GreenTea.isGtType(returns), "returns must be a GreenTea type. Use GreenTea.returns returns.")

	assert(args.tuple, "args must be a GreenTea tuple type. Use GreenTea.args to specify args.")
	assert(returns.tuple, "returns must be a GreenTea tuple type. Use GreenTea.returns returns.")

	local self: TypeRaw__DARKLUA_TYPE_bs
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
		count: RangeInput__DARKLUA_TYPE_bn?,
		raw: boolean?,
	}?
): T
	local array: boolean? = options and options.array or nil
	local countRange = if options and options.count then parseRange(options.count) else nil

	local isRaw = options and options.raw or nil

	-- note: pairs is used to avaid the __iter metamethod
	local indexerKey: Type__DARKLUA_TYPE_bt?
	local indexerValue: Type__DARKLUA_TYPE_bt?
	local indexerValues: { Type__DARKLUA_TYPE_bt } = {}
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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
	count: RangeInput__DARKLUA_TYPE_bn?,
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
		count: RangeInput__DARKLUA_TYPE_bn?,
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
		count: RangeInput__DARKLUA_TYPE_bn?,
	}?
): { [K]: V }
	return GreenTea.table({ [GreenTea.typeof(key)] = GreenTea.typeof(value) }, {
		count = options and options.count,
	})
end








local union: UnionType__DARKLUA_TYPE_bw = function<T>(...: T): ...T
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
		local value: Type__DARKLUA_TYPE_bt = GreenTea.typeof(types[index])
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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








local intersection: IntersectionType__DARKLUA_TYPE_bx = function<T>(...: T): ...T
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

	local self: TypeRaw__DARKLUA_TYPE_bs
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
function GreenTea.typecast(value: any): Type__DARKLUA_TYPE_bt
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


function GreenTea.build<T...>(...: T...): BuiltType__DARKLUA_TYPE_by<T...>
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

	gtType.type = function(_self: Type__DARKLUA_TYPE_bt)
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
	local gtType: Type__DARKLUA_TYPE_bt = GreenTea.typeof(gtType) :: any

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
	local gtType: Type__DARKLUA_TYPE_bt = GreenTea.typeof(gtType) :: any

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
	local gtType: Type__DARKLUA_TYPE_bt = GreenTea.typeof(gtType) :: any

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
	local gtType: Type__DARKLUA_TYPE_bt = GreenTea.typeof(gtType) :: any

	assert(typeof(fn) == "function", "fn must be a function")
	assert(gtType.fn ~= nil, "gtType must be a GreenTea.fn type")

	return function(...: any)
		return gtType.fn.returns:assert(fn(...))
	end :: any
end

return GreenTea
end function __DARKLUA_BUNDLE_MODULES.aD():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aD if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aD=v end return v.c end end do local function __modImpl()
local GreenTea = __DARKLUA_BUNDLE_MODULES.aD()





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
end function __DARKLUA_BUNDLE_MODULES.aE():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aE if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aE=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aE()



return module end function __DARKLUA_BUNDLE_MODULES.aF():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aF if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aF=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path
local gt = __DARKLUA_BUNDLE_MODULES.aF()



local PathType = gt.build(gt.custom(luauPath.Path.is, "Path") :: Path__DARKLUA_TYPE_bj)
local Components = getmetatable(Path.from("a"):components() :: any).__index :: Components__DARKLUA_TYPE_bF & {
	new: (path: string, prefix: any?, hasPhysicalRoot: boolean) -> Components__DARKLUA_TYPE_bF,
	is: (value: unknown) -> boolean,
}
local ComponentsType = gt.build(gt.custom(Components.is, "Components") :: Components__DARKLUA_TYPE_bF)
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
end function __DARKLUA_BUNDLE_MODULES.aG():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aG if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aG=v end return v.c end end do local function __modImpl()
local types = __DARKLUA_BUNDLE_MODULES.aG()
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path




















local PeekableComponents = {} :: PeekableComponentsImpl__DARKLUA_TYPE_bN
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

local function peekable(iter: Components__DARKLUA_TYPE_bJ): PeekableComponents__DARKLUA_TYPE_bM
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
return function(path: AsPath__DARKLUA_TYPE_bK): Path__DARKLUA_TYPE_bL
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
end function __DARKLUA_BUNDLE_MODULES.aH():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aH if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aH=v end return v.c end end do local function __modImpl()
local types = __DARKLUA_BUNDLE_MODULES.aG()
local AsPathType = types.AsPathType
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path
local process = require("@lune/process")
local normalizePath = __DARKLUA_BUNDLE_MODULES.aH()

--[=[
	@class vfs
	@private
]=]



local vfs = {}

local currentDir: Path__DARKLUA_TYPE_bO?

local cwd = normalizePath(process.cwd)

function vfs.createPath(path: AsPath__DARKLUA_TYPE_bP): Path__DARKLUA_TYPE_bO
	-- selene: allow(shadowing)
	local path = Path.from(path)
	if currentDir and not path:isAbsolute() then
		return currentDir:join(path)
	end
	return path
end

function vfs.asPathToString(asPath: AsPath__DARKLUA_TYPE_bP): string
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
function vfs.setCurrentDir(path: AsPath__DARKLUA_TYPE_bP)
	assert(AsPathType(path))

	local newCurrentDir: Path__DARKLUA_TYPE_bO = Path.from(vfs.asPathToString(path))
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
function vfs.cwd(): Path__DARKLUA_TYPE_bO
	return cwd
end

return vfs
end function __DARKLUA_BUNDLE_MODULES.aI():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aI if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aI=v end return v.c end end do local function __modImpl()
local luneFileSystem = require("@lune/fs")
local gt = __DARKLUA_BUNDLE_MODULES.aF()
local vfs = __DARKLUA_BUNDLE_MODULES.aI()
local asPathToString = vfs.asPathToString
local types = __DARKLUA_BUNDLE_MODULES.aG()

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
end function __DARKLUA_BUNDLE_MODULES.aJ():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aJ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aJ=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aJ()
local types = __DARKLUA_BUNDLE_MODULES.aG()

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




















local DirectoryPath = {} :: DirectoryPathImpl__DARKLUA_TYPE_bR
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
end function __DARKLUA_BUNDLE_MODULES.aK():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aK if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aK=v end return v.c end end do local function __modImpl()
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aJ()
local types = __DARKLUA_BUNDLE_MODULES.aG()

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
























local FilePath = {} :: FilePathImpl__DARKLUA_TYPE_bT
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
end function __DARKLUA_BUNDLE_MODULES.aL():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aL if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aL=v end return v.c end end do local function __modImpl()
local process = require("@lune/process")
local pathSeparator = process.os == "windows" and "\\" or "/"
-- selene: allow(global_usage)
_G.SYS_PATH_SEPARATOR = pathSeparator
local luauPath = __DARKLUA_BUNDLE_MODULES.aC()
local Path = luauPath.Path
local fs = __DARKLUA_BUNDLE_MODULES.aJ()
local gt = __DARKLUA_BUNDLE_MODULES.aF()
local types = __DARKLUA_BUNDLE_MODULES.aG()
local vfs = __DARKLUA_BUNDLE_MODULES.aI()
local createPath = vfs.createPath
local normalizePath = __DARKLUA_BUNDLE_MODULES.aH()
local cwd = vfs.cwd
local DirectoryPath = __DARKLUA_BUNDLE_MODULES.aK()
local luneFileSystem = require("@lune/fs")
local FilePath = __DARKLUA_BUNDLE_MODULES.aL()
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
pathfs.Component = getmetatable(Path.from("a"):components():collect()[1] :: any).__index :: Component__DARKLUA_TYPE_b2 & {
	normal: (value: string) -> Component__DARKLUA_TYPE_b2,
	rootDir: () -> Component__DARKLUA_TYPE_b2,
	curDir: () -> Component__DARKLUA_TYPE_b2,
	parentDir: () -> Component__DARKLUA_TYPE_b2,
	prefix: (raw: string, prefix: any) -> Component__DARKLUA_TYPE_b2,
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
function pathfs.findFile(filePath: typeof(AsPathType:type())): FilePath__DARKLUA_TYPE_bV?
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
function pathfs.findDir(dirPath: typeof(AsPathType:type())): DirectoryPath__DARKLUA_TYPE_bU?
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


















local function hashDirEntry(entry: DirEntry__DARKLUA_TYPE_b3): string
	return entry.path:toString()
end

local function directoryToPath(dir: typeof(directoryType:type())): typeof(PathType:type())
	local path: typeof(PathType:type()) = if DirectoryPath.is(dir)
		then (dir :: DirectoryPath__DARKLUA_TYPE_bU).path
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
function pathfs.getEntries(directory: typeof(directoryType:type())): { DirEntry__DARKLUA_TYPE_b3 }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry__DARKLUA_TYPE_b3 } = {}

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
function pathfs.getDescendantEntries(directory: typeof(directoryType:type())): { DirEntry__DARKLUA_TYPE_b3 }
	assert(directoryType(directory))

	-- selene: allow(shadowing)
	local directory = directoryToPath(directory)
	local entries: { DirEntry__DARKLUA_TYPE_b3 } = {}

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

			for _, deepEntry: DirEntry__DARKLUA_TYPE_b3 in deepEntries do
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
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_b3 },
	directory: typeof(directoryType:type()),
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onAdded))

	local oldEntries: { [string]: DirEntry__DARKLUA_TYPE_b3 } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry__DARKLUA_TYPE_b3 } = {}
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
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
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
	onAdded: typeof(callbackType:type() :: (addedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryAdded is deprecated and will be removed in future releases")

	return watchEntryAdded(pathfs.getDescendantEntries, directory, onAdded)
end

local function watchEntryRemoved(
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_b3 },
	directory: typeof(directoryType:type()),
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
): thread
	assert(directoryType(directory))
	assert(callbackType(onRemoved))

	local oldEntries: { [string]: DirEntry__DARKLUA_TYPE_b3 } = {}
	for _, entry in getEntries(directory) do
		oldEntries[hashDirEntry(entry)] = entry
	end

	return task.spawn(function()
		while true do
			local newEntries: { [string]: DirEntry__DARKLUA_TYPE_b3 } = {}
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
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
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
	onRemoved: typeof(callbackType:type() :: (removedEntry: DirEntry__DARKLUA_TYPE_b3) -> ())
): thread
	-- selene: allow(undefined_variable)
	warn("pathfs.watchDescendantEntryRemoved is deprecated and will be removed in future releases")

	return watchEntryRemoved(pathfs.getDescendantEntries, directory, onRemoved)
end

local FileOrAsPathType = gt.build(gt.union(
	gt.custom(FilePath.is, "FilePath"),
	AsPathType:type()
))

local function fileOrAsPathToPath(fileOrPath: typeof(FileOrAsPathType:type())): Path__DARKLUA_TYPE_b0
	return createPath(if FilePath.is(fileOrPath) then (fileOrPath :: FilePath__DARKLUA_TYPE_bV).path else fileOrPath :: AsPath__DARKLUA_TYPE_b1)
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
	getEntries: (directory: typeof(directoryType:type())) -> { DirEntry__DARKLUA_TYPE_b3 },
	directory: typeof(directoryType:type()),
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_b3) -> (() -> ())?)
): () -> ()
	assert(directoryType(directory))
	assert(callbackType(callback))

	local entryValues: {
		[string]: EntryValue__DARKLUA_TYPE_b5?,
	} = {}
	local disconnected = false
	local function attemptStartup(entryValue: EntryValue__DARKLUA_TYPE_b5)
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

	local function attemptCleanup(entryValue: EntryValue__DARKLUA_TYPE_b5)
		local cleanup = entryValue.stateOrCleanup
		entryValue.stateOrCleanup = "__dead__"
		if type(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	local function onAdded(entry: DirEntry__DARKLUA_TYPE_b3)
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

	local function onRemoved(entry: DirEntry__DARKLUA_TYPE_b3)
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
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_b3) -> (() -> ())?)
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
	callback: typeof(callbackType:type() :: (entry: DirEntry__DARKLUA_TYPE_b3) -> (() -> ())?)
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
end function __DARKLUA_BUNDLE_MODULES.aM():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aM if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aM=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aM()











return module end function __DARKLUA_BUNDLE_MODULES.aN():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aN if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aN=v end return v.c end end do local function __modImpl()--!nocheck
-- ROBLOX NOTE: inline stringReplaceAll to keep ChalkLua as one file

local function stringReplaceAll(string_, substring, replacer)
	local index = string.find(string_, substring, 1, true)
	if index == nil then
		return string_
	end
	local substringLength = #substring
	local endIndex = 1
	local returnValue = ""
	repeat
		returnValue ..= string.sub(string_, endIndex, index - 1) .. substring .. replacer
		endIndex = index + substringLength
		index = string.find(string_, substring, endIndex, true)
	until not (index ~= nil)
	returnValue ..= string.sub(string_, endIndex)
	return returnValue
end

-- ROBLOX NOTE: inline stringEncaseCRLFWithFirstIndex to keep ChalkLua as one file
local function stringEncaseCRLFWithFirstIndex(string_, prefix, postfix, index)
	local endIndex = 1
	local returnValue = ""
	repeat
		local gotCR = string.sub(string_, index - 1, index - 1) == "\r"
		returnValue ..= string.sub(string_, endIndex, if gotCR then index - 2 else index - 1) .. prefix .. (if gotCR
			then "\r\n"
			else "\n") .. postfix
		endIndex = index + 1
		index = string.find(string_, "\n", endIndex)
	until not (index ~= nil)
	returnValue ..= string.sub(string_, endIndex)
	return returnValue
end

local ansiStyles = {
	modifier = {
		reset = { 0, 0 },
		bold = { 1, 22 },
		dim = { 2, 22 },
		italic = { 3, 23 },
		underline = { 4, 24 },
		overline = { 53, 55 },
		inverse = { 7, 27 },
		hidden = { 8, 28 },
		strikethrough = { 9, 29 },
	},

	color = {
		black = { 30, 39 },
		red = { 31, 39 },
		green = { 32, 39 },
		yellow = { 33, 39 },
		blue = { 34, 39 },
		magenta = { 35, 39 },
		cyan = { 36, 39 },
		white = { 37, 39 },

		-- bright color
		blackBright = { 90, 39 },
		gray = { 90, 39 },
		grey = { 90, 39 },
		redBright = { 91, 39 },
		greenBright = { 92, 39 },
		yellowBright = { 93, 39 },
		blueBright = { 94, 39 },
		magentaBright = { 95, 39 },
		cyanBright = { 96, 39 },
		whiteBright = { 97, 39 },
	},

	bgColor = {
		bgBlack = { 40, 49 },
		bgRed = { 41, 49 },
		bgGreen = { 42, 49 },
		bgYellow = { 43, 49 },
		bgBlue = { 44, 49 },
		bgMagenta = { 45, 49 },
		bgCyan = { 46, 49 },
		bgWhite = { 47, 49 },

		-- bright color
		bgBlackBright = { 100, 49 },
		bgGray = { 100, 49 },
		bgGrey = { 100, 49 },
		bgRedBright = { 101, 49 },
		bgGreenBright = { 102, 49 },
		bgYellowBright = { 103, 49 },
		bgBlueBright = { 104, 49 },
		bgMagentaBright = { 105, 49 },
		bgCyanBright = { 106, 49 },
		bgWhiteBright = { 107, 49 },
	},
}

local ansi16 = "%c[%dm"
local ansi256 = "%c[%d;5;%dm"
local ESC = 27
local ANSI_SET_FOREGROUND = 38
local ANSI_SET_BACKGROUND = 48

local styles = {}

for groupName, group in pairs(ansiStyles) do
	for styleName, style in pairs(group) do
		styles[styleName] = {
			open = string.format(ansi16, ESC, style[1]),
			close = string.format(ansi16, ESC, style[2]),
		}
	end
end

local createStyler
local applyStyle

local function compositeStyler(style, otherStyle)
	return createStyler(style.open .. otherStyle.open, otherStyle.close .. style.close)
end

local Chalk = { level = 2 }
if _G.LUA_ENV == "roblox" then
	-- Ansi colors are not supported in Roblox, so set level to 0.
	Chalk.level = 0
end

setmetatable(Chalk, {
	__call = function(_, str)
		if str == nil or type(str) == "string" and #str == 0 then
			return ""
		end
		return tostring(str)
	end,
})

function createStyler(open, close)
	local styler = {
		open = open,
		close = close,
	}

	setmetatable(styler, {
		__call = function(self, str)
			return applyStyle(self, str)
		end,
		__concat = function(self, other)
			return compositeStyler(self, other)
		end,
	})

	return styler
end

function applyStyle(self, str)
	if str == nil or type(str) == "string" and #str == 0 then
		return ""
	end
	if Chalk.level == 0 then
		return tostring(str)
	end

	local styler = self

	local openAll, closeAll = styler.open, styler.close
	if string.match(str, "\u{001B}") then
		-- ROBLOX deviation START: no parent styles support yet
		-- Replace any instances already present with a re-opening code
		-- otherwise only the part of the string until said closing code
		-- will be colored, and the rest will simply be 'plain'.
		str = stringReplaceAll(str, styler.close, styler.open)
		-- ROBLOX deviation END
	end

	-- We can move both next actions out of loop, because remaining actions in loop won't have
	-- any/visible effect on parts we add here. Close the styling before a linebreak and reopen
	-- after next line to fix a bleed issue on macOS: https://github.com/chalk/chalk/pull/92
	local lfIndex = string.find(str, "\n")
	if lfIndex ~= nil then
		str = stringEncaseCRLFWithFirstIndex(str, closeAll, openAll, lfIndex)
	end

	return self.open .. tostring(str) .. self.close
end

local function noStyle()
	return createStyler("", "")
end

local close = string.format(ansi16, ESC, 39)
local bgClose = string.format(ansi16, ESC, 49)
local reset = string.format(ansi16, ESC, 0)

for styleName, style in pairs(styles) do
	Chalk[styleName] = createStyler(style.open, style.close)
end

Chalk["reset"] = createStyler(reset, reset)

local function rgbToAnsi256(red, green, blue)
	if red == green and green == blue then
		if red < 8 then
			return 16
		end
		if red > 248 then
			return 231
		end

		return math.round((((red - 8) / 247) * 24) + 232)
	end

	local ansi = 16
		+ (36 * math.round(red / 255 * 5))
		+ (6 * math.round(green / 255 * 5))
		+ math.round(blue / 255 * 5)
	return ansi
end

Chalk["rgb"] = function(red, green, blue)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, close)
end

Chalk["bgRgb"] = function(red, green, blue)
	if
		type(red) ~= "number"
		or type(green) ~= "number"
		or type(blue) ~= "number"
		or red > 255
		or red < 0
		or green > 255
		or green < 0
		or blue > 255
		or blue < 0
	then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, rgbToAnsi256(red, green, blue))
	return createStyler(open, bgClose)
end

local function hexToRgb(hex)
	local red = tonumber(string.sub(hex, 2, 3), 16)
	local blue = tonumber(string.sub(hex, 4, 5), 16)
	local green = tonumber(string.sub(hex, 6, 7), 16)

	return rgbToAnsi256(red, blue, green)
end

Chalk["hex"] = function(hex)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, hexToRgb(hex))
	return createStyler(open, close)
end

Chalk["bgHex"] = function(hex)
	if type(hex) ~= "string" or string.find(hex, "#%X") ~= nil or #hex ~= 7 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, hexToRgb(hex))
	return createStyler(open, bgClose)
end

Chalk["ansi"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 30 or (ansi > 37 and ansi < 90) or ansi > 97 then
		return noStyle()
	end
	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, close)
end

Chalk["bgAnsi"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 40 or (ansi > 47 and ansi < 100) or ansi > 107 then
		return noStyle()
	end
	local open = string.format(ansi16, ESC, ansi)
	return createStyler(open, bgClose)
end

Chalk["ansi256"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_FOREGROUND, ansi)
	return createStyler(open, close)
end

Chalk["bgAnsi256"] = function(ansi)
	if type(ansi) ~= "number" or ansi < 0 or ansi > 255 then
		return noStyle()
	end
	local open = string.format(ansi256, ESC, ANSI_SET_BACKGROUND, ansi)
	return createStyler(open, bgClose)
end

return Chalk
end function __DARKLUA_BUNDLE_MODULES.aO():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aO if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aO=v end return v.c end end do local function __modImpl()











































































return {}end function __DARKLUA_BUNDLE_MODULES.aP():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aP if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aP=v end return v.c end end do local function __modImpl()
local chalk = __DARKLUA_BUNDLE_MODULES.aO()
local type = __DARKLUA_BUNDLE_MODULES.aP()


return chalk :: Chalk__DARKLUA_TYPE_cj end function __DARKLUA_BUNDLE_MODULES.aQ():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aQ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aQ=v end return v.c end end do local function __modImpl()
local module = __DARKLUA_BUNDLE_MODULES.aQ()


return module end function __DARKLUA_BUNDLE_MODULES.aR():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aR if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aR=v end return v.c end end do local function __modImpl()-- Centralized color definitions for consistent styling across the codebase

local chalk = __DARKLUA_BUNDLE_MODULES.aR()

-- Define custom colors using RGB for better saturation/control
local ERROR_RED = chalk.rgb(200, 0, 0) -- Deep saturated red
local WARNING_ORANGE = chalk.rgb(255, 140, 0) -- Orange color for warnings

-- Export color functions with appropriate modifiers
local colors = {
	error = (chalk.bold .. ERROR_RED),
	warning = (chalk.bold .. WARNING_ORANGE),
	info = chalk.cyan,
	success = chalk.green,
	grey = chalk.grey,
	cyan = chalk.cyan,
}

-- Output level color mapping for execution results
colors.levelColors = {
	Print = function(s)
		return s
	end,
	Info = colors.info,
	Warning = colors.warning,
	Error = colors.error,
}

return colors
end function __DARKLUA_BUNDLE_MODULES.aS():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aS if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aS=v end return v.c end end do local function __modImpl()-- Global constants used across rodeo


return {
	SERVE_PORT = 44872,
	ONCE_PORT = 44873,

	-- Bit positions for run context bitset
	CONTEXT_BITS = {
		isStudio = 0,
		isServer = 1,
		isClient = 2,
		isEdit = 3,
		isRunning = 4,
	},
}
end function __DARKLUA_BUNDLE_MODULES.aT():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aT if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aT=v end return v.c end end do local function __modImpl()
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local pathfs = __DARKLUA_BUNDLE_MODULES.aN()

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
end function __DARKLUA_BUNDLE_MODULES.aU():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aU if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aU=v end return v.c end end do local function __modImpl()-- Shared execution utilities for exec and once commands


local fs = require("@lune/fs")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local sourcemap = __DARKLUA_BUNDLE_MODULES.aU()

-- Build LogFilter from CLI arguments








local function buildLogFilter(args: any): LogFilter__DARKLUA_TYPE_co
	local noOutput = args["no_output"] or false

	return {
		enableWarn = not (args["no_warn"] or noOutput),
		enableError = not (args["no_error"] or noOutput),
		enableInfo = not (args["no_info"] or noOutput),
		enableOutput = not (args["no_print"] or noOutput),
		enableLogs = not noOutput,
	}
end

-- Resolve instance path from sourcemap
local function resolveInstancePath(sourcemapPath: string?, scriptFilePath: string?): string?
	if not sourcemapPath then
		return nil
	end

	if not scriptFilePath then
		stdio.write(colors.warning("Warning: Sourcemap ignored: only works with file-based scripts") .. "\n")
		return nil
	end

	local map, err = sourcemap.loadSourcemap(sourcemapPath)
	if not map then
		stdio.write(colors.error(`Error: {err or "Failed to load sourcemap"}`) .. "\n")
		return nil
	end

	local instancePath = sourcemap.findInstancePath(map, scriptFilePath)
	if not instancePath then
		stdio.write(colors.warning(`Warning: Script not found in sourcemap: {scriptFilePath}`) .. "\n")
		stdio.write(colors.cyan("Falling back to temporary module execution") .. "\n")
	end

	return instancePath
end

-- Read script content from file or inline source
local function readScriptContent(scriptPath: string?, scriptSource: string?): string
	if scriptSource then
		return scriptSource
	elseif scriptPath then
		return fs.readFile(scriptPath)
	else
		error("No script source provided")
	end
end

-- Write execution output (prints/logs) to file or stdout
local function writeExecutionOutput(text: string, outputFile: string?)
	if outputFile then
		-- Append to file
		local existingContent = ""
		if fs.isFile(outputFile) then
			existingContent = fs.readFile(outputFile)
		end
		fs.writeFile(outputFile, existingContent .. text)
	else
		stdio.write(text)
	end
end

-- Write execution result (return value JSON) to file or stdout
local function writeExecutionResult(result: string, returnFile: string?, showReturn: boolean?)
	if returnFile then
		fs.writeFile(returnFile, result)
	end

	if showReturn then
		stdio.write(result)
		stdio.write("\n")
	end
end

return {
	buildLogFilter = buildLogFilter,
	resolveInstancePath = resolveInstancePath,
	readScriptContent = readScriptContent,
	writeExecutionOutput = writeExecutionOutput,
	writeExecutionResult = writeExecutionResult,
}
end function __DARKLUA_BUNDLE_MODULES.aV():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aV if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aV=v end return v.c end end do local function __modImpl()
local fs = require("@lune/fs")
local process = require("@lune/process")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()

local function buildWithRojo(rojoProjectPath: string, outputPath: string): boolean
	local result = process.exec("rojo", {
		"build",
		rojoProjectPath,
		"-o",
		outputPath,
	})

	if not result.ok then
		stdio.write(colors.error(`Error: Failed to build plugin:\n{result.stderr}`) .. "\n")
		return false
	end

	return true
end

local function generatePluginFile(pluginPath: string, rojoProjectPath: string)
	-- Ensure plugin directory exists
	local pluginsDir = pluginPath:match("(.+)/[^/]+$")
	if pluginsDir and not fs.isDir(pluginsDir) then
		pcall(function()
			process.exec("mkdir", { "-p", pluginsDir })
		end)
	end

	-- Build directly to plugin path
	if not buildWithRojo(rojoProjectPath, pluginPath) then
		error("Failed to build plugin")
	end
end

return {
	buildWithRojo = buildWithRojo,
	generatePluginFile = generatePluginFile,
}
end function __DARKLUA_BUNDLE_MODULES.aW():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aW if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aW=v end return v.c end end do local function __modImpl()-- UUID generation for execution IDs


local function generate(): string
	local bytes = {}
	for i = 1, 16 do
		bytes[i] = string.format("%02x", math.random(0, 255))
	end
	return table.concat(bytes)
end

return {
	generate = generate,
}
end function __DARKLUA_BUNDLE_MODULES.aX():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aX if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aX=v end return v.c end end do local function __modImpl()-- Once command: One-off script execution in Studio


local fs = require("@lune/fs")
local net = require("@lune/net")
local pathfs = __DARKLUA_BUNDLE_MODULES.aN()
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local constants = __DARKLUA_BUNDLE_MODULES.aT()
local execution = __DARKLUA_BUNDLE_MODULES.aV()
local plugin = __DARKLUA_BUNDLE_MODULES.aW()
local uuid = __DARKLUA_BUNDLE_MODULES.aX()

























local CONNECTION_TIMEOUT = 60

local function parseArguments(args: any): Config__DARKLUA_TYPE_cp
	-- Determine script source: --source flag, stdin (-), or file path
	local scriptPath = nil
	local scriptSource = args.source

	if args.script then
		if args.script == "-" then
			-- Read from stdin
			scriptSource = stdio.readToEnd()
		else
			-- File path
			scriptPath = args.script
		end
	end

	return {
		scriptPath = scriptPath,
		scriptSource = scriptSource,
		place = args.place,
		sourcemap = args.sourcemap,
		outputFile = args.output,
		returnFile = args["return"],
		showReturn = args.show_return,
		logFilter = execution.buildLogFilter(args),
		cacheRequires = args.cache_requires,
	}
end

local function validateConfig(config: Config__DARKLUA_TYPE_cp)
	-- Validate that exactly one script source is provided
	if not config.scriptPath and not config.scriptSource then
		stdio.write(colors.error("Error: No script source provided. Use a file path, '-' for stdin, or --source for inline execution") .. "\n")
		process.exit(1)
	end

	if config.scriptPath and config.scriptSource then
		stdio.write(colors.error("Error: Cannot specify both a script file and --source flag") .. "\n")
		process.exit(1)
	end

	-- Validate script file exists if using file path
	if config.scriptPath and not fs.isFile(config.scriptPath) then
		stdio.write(colors.error(`Error: Script file not found: {config.scriptPath}`) .. "\n")
		process.exit(1)
	end

	if config.sourcemap and not config.place then
		stdio.write(colors.error("Error: --sourcemap requires --place to resolve instances") .. "\n")
		stdio.write(colors.cyan("Usage: rodeo once script.luau --place game.rbxl --sourcemap sourcemap.json") .. "\n")
		process.exit(1)
	end

	if config.place and not fs.isFile(config.place) then
		stdio.write(colors.error(`Error: Place file not found: {config.place}`) .. "\n")
		process.exit(1)
	end
end

local function handlePluginConnection(
	ws: any,
	executionId: string,
	scriptContent: string,
	instancePath: string?,
	logFilter: LogFilter__DARKLUA_TYPE_co,
	exitCodeRef: { value: number },
	outputFile: string?,
	returnFile: string?,
	showReturn: boolean?,
	cacheRequires: boolean?
): boolean
	local message: any = {
		type = "exec",
		executionId = executionId,
		script = scriptContent,
		logFilter = logFilter,
		cacheRequires = cacheRequires,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		if decoded.type == "output" then
			local msg = decoded :: OutputMessage__DARKLUA_TYPE_cq
			local colorFn = colors.levelColors[msg.level] or function(s)
				return s
			end
			local coloredOutput = colorFn(msg.body) .. "\n"
			execution.writeExecutionOutput(coloredOutput, outputFile)

			if msg.level == "Error" then
				exitCodeRef.value = 1
			end
		elseif decoded.type == "done" then
			local msg = decoded :: DoneMessage__DARKLUA_TYPE_cr
			if msg.result then
				execution.writeExecutionResult(msg.result, returnFile, showReturn)
			end
			return true
		end
	end

	-- Connection closed by plugin or broken
	return true
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	local scriptContent = execution.readScriptContent(config.scriptPath, config.scriptSource)
	local executionId = uuid.generate()
	local pluginPath = `{roblox.studioPluginPath()}/rodeo-once.rbxmx`
	local rojoProjectPath = pathfs.absolute(_G.PESDE_ROOT .. "/plugins/once/plugin.project.json"):toString()

	local placeToOpen = config.place
	local tempPlacePath = nil
	if placeToOpen then
		local extension = placeToOpen:match("%.([^%.]+)$") or "rbxlx"
		local tempDir = ".rodeo/.temp"

		-- Ensure temp directory exists
		if not fs.isDir(".rodeo") then
			fs.writeDir(".rodeo")
		end
		if not fs.isDir(tempDir) then
			fs.writeDir(tempDir)
		end

		tempPlacePath = `{tempDir}/rodeo-place.{extension}`

		if fs.isFile(tempPlacePath) then
			fs.removeFile(tempPlacePath)
		end

		fs.copy(placeToOpen, tempPlacePath)
		placeToOpen = tempPlacePath
	end

	plugin.generatePluginFile(pluginPath, rojoProjectPath)

	local instancePath = execution.resolveInstancePath(config.sourcemap, config.scriptPath)

	local exitCodeRef = { value = 0 }
	local isComplete = false

	-- Start WebSocket server BEFORE launching Studio
	local server = net.serve(constants.ONCE_PORT, {
		handleWebSocket = function(ws)
			isComplete = handlePluginConnection(ws, executionId, scriptContent, instancePath, config.logFilter, exitCodeRef, config.outputFile, config.returnFile, config.showReturn, config.cacheRequires)
		end,
	})

	-- Give server a moment to start listening
	task.wait(0.5)

	-- Launch Studio
	local studioArgs = if placeToOpen then { placeToOpen } else {}
	local studioProcess = process.create(roblox.studioApplicationPath(), studioArgs)

	-- Drain stdout/stderr to prevent Studio from blocking on full pipe buffers
	task.spawn(function()
		while studioProcess.stdout:read() do
			continue
		end
	end)
	task.spawn(function()
		while studioProcess.stderr:read() do
			continue
		end
	end)

	local elapsed = 0
	while not isComplete and elapsed < CONNECTION_TIMEOUT do
		task.wait(0.5)
		elapsed += 0.5
	end

	server.stop()
	pcall(function()
		studioProcess:kill()
	end)

	if fs.isFile(pluginPath) then
		fs.removeFile(pluginPath)
	end
	if tempPlacePath and fs.isFile(tempPlacePath) then
		fs.removeFile(tempPlacePath)
	end

	if not isComplete then
		stdio.write(colors.error("Error: Timeout waiting for execution to complete") .. "\n")
		process.exit(2)
	end

	process.exit(exitCodeRef.value)
end

return main
end function __DARKLUA_BUNDLE_MODULES.aY():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aY if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aY=v end return v.c end end do local function __modImpl()
























local ExecConnection = {}
ExecConnection.__index = ExecConnection

function ExecConnection.new(ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter__DARKLUA_TYPE_cs, cacheRequires: boolean?): ExecConnection__DARKLUA_TYPE_ct
	local self = setmetatable({}, ExecConnection)
	self.ws = ws
	self.executionId = executionId
	self.script = script
	self.instancePath = instancePath
	self.filterBits = filterBits
	self.filterMask = filterMask
	self.logFilter = logFilter
	self.cacheRequires = cacheRequires
	self.queuedAt = os.time()
	return (self :: any) :: ExecConnection__DARKLUA_TYPE_ct
end

function ExecConnection:send(data: string)
	self.ws:send(data)
end

function ExecConnection:close()
	self.ws:close()
end

return ExecConnection
end function __DARKLUA_BUNDLE_MODULES.aZ():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.aZ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.aZ=v end return v.c end end do local function __modImpl()
local serde = require("@lune/serde")













local StudioConnection = {}
StudioConnection.__index = StudioConnection

function StudioConnection.new(ws: any, bitset: number): StudioConnection__DARKLUA_TYPE_cu
	local self = setmetatable({}, StudioConnection)
	self.ws = ws
	self.connected = true
	self.bitset = bitset
	self.connectedAt = os.time()
	return (self :: any) :: StudioConnection__DARKLUA_TYPE_cu
end

function StudioConnection:send(data: string)
	self.ws:send(data)
end

function StudioConnection:close()
	self.connected = false
	self.ws:close()
end

function StudioConnection:isConnected(): boolean
	return self.connected
end

return StudioConnection
end function __DARKLUA_BUNDLE_MODULES.a_():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a_ if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a_=v end return v.c end end do local function __modImpl()-- Output utilities for formatted terminal printing


local chalk = __DARKLUA_BUNDLE_MODULES.aR()
local constants = __DARKLUA_BUNDLE_MODULES.aT()

local function formatBitset(bitsetValue: number, filterMask: number?): string
	local parts = {}
	local contextOrder = {
		{ name = "studio", bit = constants.CONTEXT_BITS.isStudio },
		{ name = "server", bit = constants.CONTEXT_BITS.isServer },
		{ name = "client", bit = constants.CONTEXT_BITS.isClient },
		{ name = "edit", bit = constants.CONTEXT_BITS.isEdit },
		{ name = "running", bit = constants.CONTEXT_BITS.isRunning },
	}

	for _, context in ipairs(contextOrder) do
		local bitMask = bit32.lshift(1, context.bit)
		local isSet = bit32.band(bitsetValue, bitMask) ~= 0

		-- Only include if no filter mask, or if filter mask includes this bit
		if not filterMask or bit32.band(filterMask, bitMask) ~= 0 then
			local colorFn = isSet and chalk.green or chalk.red
			local bitValue = isSet and "1" or "0"
			table.insert(parts, chalk.grey(context.name .. ":") .. " " .. colorFn(bitValue))
		end
	end

	return table.concat(parts, ", ")
end

local function formatBitsetShort(bitset: number): string
	local bits = {
		bit32.band(bit32.rshift(bitset, constants.CONTEXT_BITS.isStudio), 1),
		bit32.band(bit32.rshift(bitset, constants.CONTEXT_BITS.isServer), 1),
		bit32.band(bit32.rshift(bitset, constants.CONTEXT_BITS.isClient), 1),
		bit32.band(bit32.rshift(bitset, constants.CONTEXT_BITS.isEdit), 1),
		bit32.band(bit32.rshift(bitset, constants.CONTEXT_BITS.isRunning), 1),
	}

	local parts = {}
	for _, bit in ipairs(bits) do
		local colorFn = bit == 1 and chalk.green or chalk.red
		table.insert(parts, colorFn(tostring(bit)))
	end

	return table.concat(parts, "")
end

local function formatShortLog(studioId: string, bitset: number, executionId: string?): string
	local shortId = studioId:sub(1, 8)
	local bitsetShort = formatBitsetShort(bitset)

	if executionId then
		local execShort = executionId:sub(6, 13) -- Skip "rodeo-" prefix
		return chalk.grey("[id:") .. " " .. shortId .. chalk.grey("] [") .. bitsetShort .. chalk.grey("]") .. " " .. execShort
	else
		return chalk.grey("[id:") .. " " .. shortId .. chalk.grey("] [") .. bitsetShort .. chalk.grey("]")
	end
end

return {
	formatBitset = formatBitset,
	formatBitsetShort = formatBitsetShort,
	formatShortLog = formatShortLog,
}
end function __DARKLUA_BUNDLE_MODULES.a0():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a0 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a0=v end return v.c end end do local function __modImpl()
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local ExecConnection = __DARKLUA_BUNDLE_MODULES.aZ()
local StudioConnection = __DARKLUA_BUNDLE_MODULES.a_()
local output = __DARKLUA_BUNDLE_MODULES.a0()




















local VmPipeline = {}
VmPipeline.__index = VmPipeline

function VmPipeline.new(bitset: number, studioId: string, studio: StudioConnection__DARKLUA_TYPE_cv): VmPipeline__DARKLUA_TYPE_cx
	local self = setmetatable({}, VmPipeline)
	self.bitset = bitset
	self.studioId = studioId
	self.studio = studio
	self.execQueue = {}
	self.activeExecution = nil
	return (self :: any) :: VmPipeline__DARKLUA_TYPE_cx
end

local function processQueue(self: VmPipeline__DARKLUA_TYPE_cx)
	if #self.execQueue == 0 then
		return
	end

	-- Check if Studio is idle
	if not self.studio:isConnected() or self.activeExecution then
		return
	end

	-- Get first exec from queue
	local exec = self.execQueue[1]
	table.remove(self.execQueue, 1)

	-- Set as active execution
	self.activeExecution = exec

	stdio.write(`Execution started: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

	-- Send to Studio
	local message: any = {
		type = "exec",
		executionId = exec.executionId,
		script = exec.script,
		logFilter = exec.logFilter,
		cacheRequires = exec.cacheRequires,
	}

	if exec.instancePath then
		message.instancePath = exec.instancePath
	end

	self.studio:send(serde.encode("json", message))
end

function VmPipeline:enqueue(exec: ExecConnection__DARKLUA_TYPE_cw)
	table.insert(self.execQueue, exec)

	exec:send(serde.encode("json", {
		type = "queued",
		executionId = exec.executionId,
		position = #self.execQueue,
	}))

	stdio.write(`Queued execution: {output.formatShortLog(self.studioId, self.bitset, exec.executionId)}\n`)

	-- Try to process immediately
	processQueue(self)
end

function VmPipeline:completeExecution(executionId: string)
	if not self.activeExecution or self.activeExecution.executionId ~= executionId then
		return
	end

	stdio.write(`Execution complete: {output.formatShortLog(self.studioId, self.bitset, executionId)}\n`)

	-- Clear active execution
	self.activeExecution = nil

	-- Process next in queue
	processQueue(self)
end

function VmPipeline:forwardOutput(executionId: string, message: string)
	-- Check if this is the active execution
	if self.activeExecution and self.activeExecution.executionId == executionId then
		local e = self.activeExecution :: ExecConnection__DARKLUA_TYPE_cw
		e:send(message)
	end
end

function VmPipeline:disconnect()
	stdio.write(`{colors.grey('VM disconnected: [id:')} {self.studioId}{colors.grey('] [')} {output.formatBitset(self.bitset)}{colors.grey(']')}\n`)

	self.studio:close()

	-- Notify active execution if any
	if self.activeExecution then
		local exec = self.activeExecution :: ExecConnection__DARKLUA_TYPE_cw
		exec:send(serde.encode("json", {
			type = "disconnect",
			executionId = exec.executionId,
		}))
		exec:close()
	end

	-- Notify all queued executions
	for _, exec in ipairs(self.execQueue) do
		local e = exec :: ExecConnection__DARKLUA_TYPE_cw
		e:send(serde.encode("json", {
			type = "disconnect",
			executionId = e.executionId,
		}))
		e:close()
	end
end

function VmPipeline:getQueueLength(): number
	return #self.execQueue
end

function VmPipeline:isIdle(): boolean
	return self.studio:isConnected() and not self.activeExecution
end

return VmPipeline
end function __DARKLUA_BUNDLE_MODULES.a1():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a1 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a1=v end return v.c end end do local function __modImpl()--!nonstrict


local net = require("@lune/net")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")
local task = require("@lune/task")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local ExecConnection = __DARKLUA_BUNDLE_MODULES.aZ()
local StudioConnection = __DARKLUA_BUNDLE_MODULES.a_()
local VmPipeline = __DARKLUA_BUNDLE_MODULES.a1()
local constants = __DARKLUA_BUNDLE_MODULES.aT()
local output = __DARKLUA_BUNDLE_MODULES.a0()

-- Nested map: bitset -> studioId -> VmPipeline




local pipelines: { [number]: { [string]: VmPipeline__DARKLUA_TYPE_cA } } = {}

-- Pending executions waiting for a matching VM to connect
local pendingExecutions: { ExecConnection__DARKLUA_TYPE_cz } = {}

local function generateId(): string
	local random = math.random
	return string.format("%08x-%04x-%04x-%04x-%012x", random(0, 0xffffffff), random(0, 0xffff), random(0, 0xffff), random(0, 0xffff), random(0, 0xffffffffffff))
end







local function findMatchingVmPipelines(filterBits: number, filterMask: number): { MatchingVm__DARKLUA_TYPE_cB }
	local matches = {}
	for vmBitset, vmMap in pairs(pipelines) do
		if bit32.band(vmBitset, filterMask) == filterBits then
			for studioId, vmPipeline in pairs(vmMap) do
				table.insert(matches, {
					bitset = vmBitset,
					studioId = studioId,
					pipeline = vmPipeline,
				})
			end
		end
	end
	return matches
end

local function selectBestVmPipeline(matches: { MatchingVm__DARKLUA_TYPE_cB }): MatchingVm__DARKLUA_TYPE_cB?
	if #matches == 0 then
		return nil
	end

	-- Load balancing: select VM with shortest queue
	local best = matches[1]
	for i = 2, #matches do
		if matches[i].pipeline:getQueueLength() < best.pipeline:getQueueLength() then
			best = matches[i]
		end
	end

	return best
end

local function cleanupEmptyPipelines()
	for bitset, vmMap in pairs(pipelines) do
		local hasAnyVms = false
		for _ in pairs(vmMap) do
			hasAnyVms = true
			break
		end
		if not hasAnyVms then
			pipelines[bitset] = nil
		end
	end
end

local function removePipelineFromMap(bitset: number, studioId: string)
	-- Remove from pipeline map
	if pipelines[bitset] then
		pipelines[bitset][studioId] = nil
	end

	cleanupEmptyPipelines()
end

local function processPendingExecutions()
	-- Try to assign pending executions to newly connected VMs
	local i = 1
	while i <= #pendingExecutions do
		local exec = pendingExecutions[i]
		local matchingVms = findMatchingVmPipelines(exec.filterBits, exec.filterMask)

		if #matchingVms > 0 then
			-- Found a matching VM, remove from pending and enqueue
			table.remove(pendingExecutions, i)
			local bestVm = selectBestVmPipeline(matchingVms)
			if bestVm then
				stdio.write(colors.success(`Processing pending execution: {exec.executionId}`) .. "\n")
				bestVm.pipeline:enqueue(exec)
			end
		else
			-- Still no match, keep in pending
			i = i + 1
		end
	end
end

local function handleExecClient(ws: any)
	local clientExecutionId = nil
	local execConnection = nil

	while true do
		local success, message = pcall(function()
			return ws:next()
		end)

		if not success then
			-- Connection reset or closed unexpectedly
			if clientExecutionId then
				stdio.write(colors.grey(`Execution cancelled: {clientExecutionId}`) .. "\n")
			end
			break
		end

		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		if decoded.type == "submit" then
			clientExecutionId = decoded.executionId
			local filterBits = decoded.filterBits or 0
			local filterMask = decoded.filterMask or 0
			local logFilter = decoded.logFilter or {
				enableWarn = true,
				enableError = true,
				enableInfo = true,
				enableOutput = true,
				enableLogs = true,
			}
			execConnection = ExecConnection.new(ws, clientExecutionId, decoded.script, decoded.instancePath, filterBits, filterMask, logFilter, decoded.cacheRequires)

			-- Find matching VM pipelines
			local matchingVms = findMatchingVmPipelines(filterBits, filterMask)

			if #matchingVms == 0 then
				-- No matching VMs - add to pending queue
				table.insert(pendingExecutions, execConnection)
				stdio.write(`Waiting for VM: [{output.formatBitset(filterBits, filterMask)}]\n`)
			else
				-- Use load balancing to select best VM
				local bestVm = selectBestVmPipeline(matchingVms)
				if bestVm then
					bestVm.pipeline:enqueue(execConnection)
				end
			end
		end
	end

	-- Cleanup: remove from pending queue if still there
	if execConnection and clientExecutionId then
		for i, pending in ipairs(pendingExecutions) do
			if pending.executionId == clientExecutionId then
				table.remove(pendingExecutions, i)
				break
			end
		end
	end
end

local function handleStudioClient(ws: any, vmBitset: number)
	local studioId = generateId()
	local studioConnection = StudioConnection.new(ws, vmBitset)

	-- Create VmPipeline for this Studio
	local vmPipeline = VmPipeline.new(vmBitset, studioId, studioConnection)

	-- Add to nested pipeline map
	if not pipelines[vmBitset] then
		pipelines[vmBitset] = {}
	end
	pipelines[vmBitset][studioId] = vmPipeline

	stdio.write(`VM connected: {colors.grey('[id:')} {studioId}{colors.grey('] [')} {output.formatBitset(vmBitset)}{colors.grey(']')}\n`)

	-- Process any pending executions that might match this new VM
	processPendingExecutions()

	while true do
		local success, message = pcall(function()
			return ws:next()
		end)

		if not success then
			-- Connection reset or closed unexpectedly
			break
		end

		if not message then
			break
		end

		local decoded = serde.decode("json", message)

		-- Forward output to exec client
		vmPipeline:forwardOutput(decoded.executionId, message)

		if decoded.type == "done" then
			vmPipeline:completeExecution(decoded.executionId)
		end
	end

	-- Handle disconnect
	vmPipeline:disconnect()

	removePipelineFromMap(vmBitset, studioId)
end

local function main(_args: any)
	stdio.write(colors.cyan(`Starting server on port {constants.SERVE_PORT}`) .. "\n")
	stdio.write(colors.cyan(`Waiting for Studio plugin to connect...`) .. "\n")

	local _server = net.serve(constants.SERVE_PORT, {
		handleRequest = function(request)
			if request.path == "/health" then
				local contextStatus = {}
				local totalVms = 0
				local totalQueued = 0

				for bitset, vmMap in pairs(pipelines) do
					local vms = {}
					local contextQueued = 0

					for studioId, vmPipeline in pairs(vmMap) do
						local queueLength = vmPipeline:getQueueLength()
						table.insert(vms, {
							studioId = studioId,
							queueLength = queueLength,
							isIdle = vmPipeline:isIdle(),
						})
						contextQueued = contextQueued + queueLength
						totalVms = totalVms + 1
					end

					table.insert(contextStatus, {
						bitset = bitset,
						vmCount = #vms,
						totalQueued = contextQueued,
						vms = vms,
					})
					totalQueued = totalQueued + contextQueued
				end

				return {
					status = 200,
					headers = {
						["Content-Type"] = "application/json",
					},
					body = serde.encode("json", {
						contextCount = #contextStatus,
						totalVms = totalVms,
						totalQueued = totalQueued,
						contexts = contextStatus,
					}),
				}
			end

			return {
				status = 404,
				body = "Not Found",
			}
		end,

		handleWebSocket = function(socket)
			local firstMessage = socket:next()
			if not firstMessage then
				socket:close()
				return
			end

			local success, decoded = pcall(serde.decode, "json", firstMessage)
			if not success or not decoded.clientType then
				socket:close()
				return
			end

			if decoded.clientType == "studio" then
				local vmBitset = decoded.contextBitset or 0
				handleStudioClient(socket, vmBitset)
			elseif decoded.clientType == "exec" then
				handleExecClient(socket)
			else
				socket:close()
			end
		end,
	})

	stdio.write(`[serve] Server started.\n`)

	while true do
		task.wait(1)
	end
end

return main
end function __DARKLUA_BUNDLE_MODULES.a2():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a2 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a2=v end return v.c end end do local function __modImpl()-- Exec command: Execute script via persistent serve server


local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local constants = __DARKLUA_BUNDLE_MODULES.aT()
local execution = __DARKLUA_BUNDLE_MODULES.aV()
local sourcemap = __DARKLUA_BUNDLE_MODULES.aU()
local uuid = __DARKLUA_BUNDLE_MODULES.aX()














local function parseContextFlags(args: any): (number, number)
	local filterBits = 0
	local filterMask = 0

	local contextMap = {
		studio = constants.CONTEXT_BITS.isStudio,
		client = constants.CONTEXT_BITS.isClient,
		server = constants.CONTEXT_BITS.isServer,
		edit = constants.CONTEXT_BITS.isEdit,
		running = constants.CONTEXT_BITS.isRunning,
	}

	for flagName, bitPos in pairs(contextMap) do
		local value = args[flagName]
		if value ~= nil then
			local bitMask = bit32.lshift(1, bitPos)
			filterMask = bit32.bor(filterMask, bitMask)

			if value == 1 then
				filterBits = bit32.bor(filterBits, bitMask)
			elseif value == 0 then
				filterBits = bit32.band(filterBits, bit32.bnot(bitMask))
			end
		end
	end

	return filterBits, filterMask
end

local function parseArguments(args: any): Config__DARKLUA_TYPE_cC
	local filterBits, filterMask = parseContextFlags(args)

	-- Determine script source: --source flag, stdin (-), or file path
	local scriptPath = nil
	local scriptSource = args.source

	if args.script then
		if args.script == "-" then
			-- Read from stdin
			scriptSource = stdio.readToEnd()
		else
			-- File path
			scriptPath = args.script
		end
	end

	return {
		scriptPath = scriptPath,
		scriptSource = scriptSource,
		sourcemap = args.sourcemap,
		outputFile = args.output,
		returnFile = args["return"],
		showReturn = args.show_return,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = execution.buildLogFilter(args),
		cacheRequires = args.cache_requires,
	}
end

local function validateConfig(config: Config__DARKLUA_TYPE_cC)
	-- Validate that exactly one script source is provided
	if not config.scriptPath and not config.scriptSource then
		stdio.write(colors.error("Error: No script source provided. Use a file path, '-' for stdin, or --source for inline execution") .. "\n")
		process.exit(1)
	end

	if config.scriptPath and config.scriptSource then
		stdio.write(colors.error("Error: Cannot specify both a script file and --source flag") .. "\n")
		process.exit(1)
	end

	-- Validate script file exists if using file path
	if config.scriptPath and not fs.isFile(config.scriptPath) then
		stdio.write(colors.error(`Error: Script file not found: {config.scriptPath}`) .. "\n")
		process.exit(1)
	end
end

local function checkServerHealth(port: number): boolean
	local success, response = pcall(function()
		return net.request({
			url = `http://localhost:{port}/health`,
			method = "GET",
		})
	end)

	return success and response.ok
end

local function connectToServer(port: number): any
	return net.socket(`ws://localhost:{port}`)
end

local function identifyClient(ws: any)
	ws:send(serde.encode("json", {
		clientType = "exec",
	}))
end

local function submitScript(ws: any, executionId: string, script: string, instancePath: string?, filterBits: number, filterMask: number, logFilter: LogFilter, cacheRequires: boolean?)
	local message: any = {
		type = "submit",
		script = script,
		executionId = executionId,
		filterBits = filterBits,
		filterMask = filterMask,
		logFilter = logFilter,
		cacheRequires = cacheRequires,
	}

	if instancePath then
		message.instancePath = instancePath
	end

	ws:send(serde.encode("json", message))
end

local function handleMessage(decoded: any, exitCodeRef: { value: number }, outputFile: string?, returnFile: string?, showReturn: boolean?): boolean
	if decoded.type == "queued" then
		if decoded.waiting then
			stdio.write(colors.cyan(`Waiting: {decoded.waiting}`) .. "\n")
		elseif decoded.matches then
			-- Queued successfully to matching studios
		end
	elseif decoded.type == "output" then
		local colorFn = colors.levelColors[decoded.level] or function(s)
			return s
		end
		local coloredOutput = colorFn(decoded.body) .. "\n"
		execution.writeExecutionOutput(coloredOutput, outputFile)
		if decoded.level == "Error" then
			exitCodeRef.value = 1
		end
	elseif decoded.type == "done" then
		if decoded.result then
			execution.writeExecutionResult(decoded.result, returnFile, showReturn)
		end
		return true
	elseif decoded.type == "disconnect" then
		stdio.write(colors.error("Error: Studio disconnected") .. "\n")
		exitCodeRef.value = 2
		return true
	end

	return false
end

local function main(args: any)
	local config = parseArguments(args)
	validateConfig(config)

	-- Auto-detect sourcemap if not explicitly provided
	if not config.sourcemap and config.scriptPath then
		local autoDetectedPath = sourcemap.findSourcemapInTree()
		if autoDetectedPath then
			config.sourcemap = autoDetectedPath
			-- stdio.write(colors.cyan(`Using sourcemap: {autoDetectedPath}`) .. "\n")
		end
	end

	if not checkServerHealth(constants.SERVE_PORT) then
		stdio.write(colors.error(`Error: No rodeo server found on port {constants.SERVE_PORT}. Run 'rodeo serve' first.`) .. "\n")
		process.exit(1)
	end

	local instancePath = execution.resolveInstancePath(config.sourcemap, config.scriptPath)
	local scriptContent = execution.readScriptContent(config.scriptPath, config.scriptSource)
	local executionId = uuid.generate()
	local exitCodeRef = { value = 0 }

	local ws = connectToServer(constants.SERVE_PORT)
	identifyClient(ws)
	submitScript(ws, executionId, scriptContent, instancePath, config.filterBits, config.filterMask, config.logFilter, config.cacheRequires)

	while true do
		local message = ws:next()
		if not message then
			break
		end

		local decoded = serde.decode("json", message)
		local isDone = handleMessage(decoded, exitCodeRef, config.outputFile, config.returnFile, config.showReturn)

		if isDone then
			ws:close()
			break
		end
	end

	process.exit(exitCodeRef.value)
end

return main
end function __DARKLUA_BUNDLE_MODULES.a3():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a3 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a3=v end return v.c end end do local function __modImpl()
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local pathfs = __DARKLUA_BUNDLE_MODULES.aN()
local plugin = __DARKLUA_BUNDLE_MODULES.aW()

local function main(_args: any)
	stdio.write(colors.cyan("Building serve plugin...") .. "\n")

	local pluginPath = `{roblox.studioPluginPath()}/rodeo-serve.rbxmx`
	local rojoProjectPath = pathfs.absolute(_G.PESDE_ROOT .. "/plugins/serve/plugin.project.json"):toString()

	plugin.generatePluginFile(pluginPath, rojoProjectPath)

	stdio.write(colors.cyan(`Plugin installed to: {pluginPath}`) .. "\n")
	stdio.write(colors.cyan("Restart Roblox Studio to load the plugin") .. "\n")

	process.exit(0)
end

return main
end function __DARKLUA_BUNDLE_MODULES.a4():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a4 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a4=v end return v.c end end do local function __modImpl()-- Status command: Check if rodeo serve is running


local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local colors = __DARKLUA_BUNDLE_MODULES.aS()
local constants = __DARKLUA_BUNDLE_MODULES.aT()
local output = __DARKLUA_BUNDLE_MODULES.a0()

local function checkServerStatus(port: number): (boolean, any?)
	local success, response = pcall(function()
		return net.request({
			url = `http://localhost:{port}/health`,
			method = "GET",
		})
	end)

	if not success then
		return false, nil
	end

	if not response.ok then
		return false, nil
	end

	local healthData = serde.decode("json", response.body)
	return true, healthData
end

local function formatStatus(healthData: any)
	stdio.write(colors.success("rodeo serve is running") .. "\n")
	stdio.write(colors.cyan(`Port: {constants.SERVE_PORT}`) .. "\n")
	stdio.write(colors.cyan(`Total VMs: {healthData.totalVms}`) .. "\n")
	stdio.write(colors.cyan(`Total Queued: {healthData.totalQueued}`) .. "\n")
	stdio.write(colors.cyan(`Context Groups: {healthData.contextCount}`) .. "\n")

	if healthData.contextCount > 0 then
		print("")
		stdio.write(colors.cyan("Connected Studios:") .. "\n")
		for _, context in ipairs(healthData.contexts) do
			local bitsetFormatted = output.formatBitsetShort(context.bitset)
			stdio.write(colors.grey(`  Context [{bitsetFormatted}]: {context.vmCount} VM(s), {context.totalQueued} queued`) .. "\n")

			for _, vm in ipairs(context.vms) do
				local studioIdShort = vm.studioId:sub(1, 8)
				local idleStatus = vm.isIdle and "idle" or "busy"
				local idleColorFn = vm.isIdle and colors.success or colors.warning
				stdio.write(`{colors.grey(`    - {studioIdShort}: {vm.queueLength} in queue, `)}{idleColorFn(idleStatus)}\n`)
			end
		end
	end
end

local function main(args: any)
	local isRunning, healthData = checkServerStatus(constants.SERVE_PORT)

	if not isRunning then
		stdio.write(colors.error(`Error: rodeo serve is not running on port {constants.SERVE_PORT}`) .. "\n")
		process.exit(1)
	end

	formatStatus(healthData)
	process.exit(0)
end

return main
end function __DARKLUA_BUNDLE_MODULES.a5():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a5 if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a5=v end return v.c end end end-- rodeo CLI Router
-- Routes commands to appropriate handlers

local argparse = __DARKLUA_BUNDLE_MODULES.b()

local function main()
	local parser = argparse("rodeo", "Run Luau code inside Roblox Studio")

	-- Define once command
	local onceCmd = parser:command("once", "Execute script once in Studio (ephemeral)")
	onceCmd:argument("script", "Path to the script to execute, or '-' for stdin"):args("?")
	onceCmd:option("-s --source", "Execute source code passed as string")
	onceCmd:option("--place", "Path to the place file to open")
	onceCmd:option("--sourcemap", "Path to sourcemap.json for instance resolution")
	onceCmd:option("--output", "Path to file for execution output (prints/logs)")
	onceCmd:option("--return", "Path to file for return value JSON")
	onceCmd:flag("--show-return", "Print return value to stdout")
	onceCmd:flag("--no-warn", "Disable warning output")
	onceCmd:flag("--no-error", "Disable error output")
	onceCmd:flag("--no-info", "Disable info output")
	onceCmd:flag("--no-print", "Disable print statements")
	onceCmd:flag("--no-output", "Disable all output")
	onceCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")

	-- Define serve command
	parser:command("serve", "Start persistent server for code execution")

	-- Define exec command
	local execCmd = parser:command("exec", "Execute script via running serve instance")
	execCmd:argument("script", "Path to the script to execute, or '-' for stdin"):args("?")
	execCmd:option("-s --source", "Execute source code passed as string")
	execCmd:option("--sourcemap", "Path to sourcemap.json for instance resolution")
	execCmd:option("--output", "Path to file for execution output (prints/logs)")
	execCmd:option("--return", "Path to file for return value JSON")
	execCmd:flag("--show-return", "Print return value to stdout")
	execCmd:option("--studio", "Filter: isStudio (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--client", "Filter: isClient (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--server", "Filter: isServer (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--edit", "Filter: isEdit (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:option("--running", "Filter: isRunning (0, 1, or omit for don't care)"):convert(tonumber)
	execCmd:flag("--no-warn", "Disable warning output")
	execCmd:flag("--no-error", "Disable error output")
	execCmd:flag("--no-info", "Disable info output")
	execCmd:flag("--no-print", "Disable print statements")
	execCmd:flag("--no-output", "Disable all output")
	execCmd:flag("--cache-requires", "Enable module caching (skip reloader for better performance)")

	-- Define build command
	parser:command("build", "Build and install the serve plugin")

	-- Define status command
	parser:command("status", "Check if rodeo serve is running")

	local args = parser:parse()

	-- Router: check which command was invoked and call it with parsed args
	-- When a command is selected, argparse sets result[command_name] = true
	if args.once then
		local onceCommand = __DARKLUA_BUNDLE_MODULES.aY()
		onceCommand(args)
	elseif args.serve then
		local serveCommand = __DARKLUA_BUNDLE_MODULES.a2()
		serveCommand(args)
	elseif args.exec then
		local execCommand = __DARKLUA_BUNDLE_MODULES.a3()
		execCommand(args)
	elseif args.build then
		local buildCommand = __DARKLUA_BUNDLE_MODULES.a4()
		buildCommand(args)
	elseif args.status then
		local statusCommand = __DARKLUA_BUNDLE_MODULES.a5()
		statusCommand(args)
	end
end

main()
