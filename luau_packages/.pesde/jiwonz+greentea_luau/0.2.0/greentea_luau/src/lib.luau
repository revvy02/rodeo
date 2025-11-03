local GreenTea = require("./GreenTea")

export type Cause = GreenTea.Cause
export type Type = GreenTea.Type
export type TuplePacked<T...> = GreenTea.TuplePacked<T...>

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
