--!strict
export type Option<T...> = typeof(setmetatable(
	{} :: {
		-- value to "store" T...
		-- this value doesn't exist at runtime, and is only used for typechecking
		_T: (T...) -> (),

		_n: number,
	},
	{} :: OptionImpl
))

export type OptionImpl = {
	__index: OptionImpl,
	__tostring: <T0...>(self: Option<T0...>) -> string,
	__eq: <T1...>(self: Option<T1...>, other: Option<T1...>) -> boolean,

	None: Option<...any>,
	Some: <T3...>(T3...) -> Option<T3...>,
	from: <T4>(value: T4?) -> Option<T4>,
	is: (value: unknown) -> boolean,
	isSome: <T5...>(self: Option<T5...>) -> boolean,
	isSomeAnd: <T6...>(self: Option<T6...>, f: (T6...) -> boolean) -> boolean,
	isNone: <T7...>(self: Option<T7...>) -> boolean,
	expect: <T8...>(self: Option<T8...>, message: string) -> T8...,
	unwrap: <T9...>(self: Option<T9...>) -> T9...,
	unwrapOr: <T10...>(self: Option<T10...>,T10...) -> T10...,
	unwrapOrElse: <T11...>(self: Option<T11...>, f: () -> T11...) -> T11...,
	unwrapOrNil: <T>(self: Option<T>) -> T?,
	map: <T12..., U0...>(self: Option<T12...>, f: (T12...) -> U0...) -> Option<U0...>,
	mapOr: <U, T13...>(self: Option<T13...>, default: U, f: (T13...) -> U) -> U,
	mapOrRest: <T14..., U1...>(self: Option<T14...>, f: (T14...) -> U1...,U1...) -> U1...,
	mapOrElse: <T15..., U2...>(self: Option<T15...>, default: () -> U2..., f: (T15...) -> U2...) -> U2...,
	andOpt: <T16..., U3...>(self: Option<T16...>, other: Option<U3...>) -> Option<U3...>,
	andThen: <T17..., U4...>(self: Option<T17...>, f: (T17...) -> Option<U4...>) -> Option<U4...>,
	filter: <T18...>(self: Option<T18...>, f: (T18...) -> boolean) -> Option<T18...>,
	orOpt: <T19...>(self: Option<T19...>, other: Option<T19...>) -> Option<T19...>,
	orElse: <T20...>(self: Option<T20...>, f: () -> Option<T20...>) -> Option<T20...>,
	xor: <T21...>(self: Option<T21...>, other: Option<T21...>) -> Option<T21...>,
	match: <T22..., U5...>(self: Option<T22...>, f: { Some: (T22...) -> U5..., None: () -> U5...}) -> U5...,
	join: OptionJoin,
}

-- can't join two type packs
-- stylua: ignore
type OptionJoin = 
			(<T1, U1...>(self: Option<T1>, other: Option<U1...>) -> Option<(T1, U1...)>)
		& (<T1, T2, U2...>(self: Option<T1, T2>, other: Option<U2...>) -> Option<(T1, T2, U2...)>)
		& (<T1, T2, T3, U3...>(self: Option<T1, T2, T3>, other: Option<U3...>) -> Option<(T1, T2, T3, U3...)>)
		& (<T1, T2, T3, T4, U4...>(self: Option<T1, T2, T3, T4>, other: Option<U4...>) -> Option<(T1, T2, T3, T4, U4...)>)
		& (<T1, T2, T3, T4, T5, U5...>(self: Option<T1, T2, T3, T4, T5>, other: Option<U5...>) -> Option<(T1, T2, T3, T4, T5, U5...)>)
		& (<T1, T2, T3, T4, T5, T6, U6...>(self: Option<T1, T2, T3, T4, T5, T6>, other: Option<U6...>) -> Option<(T1, T2, T3, T4, T5, T6, U6...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, U7...>(self: Option<T1, T2, T3, T4, T5, T6, T7>, other: Option<U7...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, U7...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, T8, U8...>(self: Option<T1, T2, T3, T4, T5, T6, T7, T8>, other: Option<U8...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, T8, U8...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, T8, T9, U9...>(self: Option<T1, T2, T3, T4, T5, T6, T7, T8, T9>, other: Option<U9...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, T8, T9, U9...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, U10...>(self: Option<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10>, other: Option<U10...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, U10...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, U11...>(self: Option<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11>, other: Option<U11...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, U11...)>)
		& (<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, U12...>(self: Option<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12>, other: Option<U12...>) -> Option<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, U12...)>)

--[=[
  @class Option

  Represents an optional value: `Some` and contains a value, or `None`
  and does not contain a value.

  Options can be used as an alternative to `nil` to represent the
  absence of a value. They help you avoid bugs by requiring you to
  handle the case where a value might be missing.
]=]
local Option = {} :: OptionImpl
Option.__index = Option

--[=[
  The `Option` that does not contain a value.
]=]
Option.None = table.freeze(setmetatable({ _n = 0 }, Option) :: any)

--[=[
  Creates a new `Some` with the given value.
]=]
function Option.Some(...)
	local n = select("#", ...)
	if n == 0 then
		error("Option.Some() called with no arguments", 2)
	end
	local self = setmetatable({ _n = n, ... }, Option)
	return table.freeze(self) :: any
end

--[=[
  Converts the given value to an `Option`, returning `None` if the
  value is `nil`.
]=]
function Option.from(value)
	if value == nil then
		return Option.None
	else
		return Option.Some(value)
	end
end

--[=[
	Returns `true` if the given value is an `Option`.
]=]
function Option.is(value)
	return typeof(value) == "table" and getmetatable(value :: any) == Option
end

--[=[
  Returns `true` if the option is a `Some` value.
]=]
function Option.isSome(self)
	return self._n ~= 0
end

--[=[
	Returns `true` if the option is a `Some` value and the value
	satisfies the given predicate.
]=]
function Option.isSomeAnd(self, f)
	return self._n ~= 0 and f(unpack(self :: any))
end

--[=[
  Returns `true` if the option is a `None` value.
]=]
function Option.isNone(self): boolean
	return self._n == 0
end

--[=[
  Returns the value of the option if it is `Some`, otherwise throws
  an error with the given message.
]=]
function Option.expect(self, message)
	if self._n == 0 then
		error(message, 2)
	end
	return unpack(self :: any)
end

--[=[
  Returns the value of the option if it is `Some`, otherwise throws
  an error.
]=]
function Option.unwrap(self)
	if self._n == 0 then
		error("called `Option.unwrap()` on a `None` value", 2)
	end
	return unpack(self :: any)
end

--[=[
  Returns the value of the option if it is `Some`, otherwise returns
  the given default value.
]=]
function Option.unwrapOr(self, ...)
	if self._n == 0 then
		return ...
	end
	return unpack(self :: any)
end

--[=[
  Returns the value of the option if it is `Some`, otherwise returns
  the result of calling the given function.
]=]
function Option.unwrapOrElse(self, f)
	if self._n == 0 then
		return f()
	end
	return unpack(self :: any)
end

--[=[
	Returns the value of the option if it is `Some`, otherwise returns
	`nil`. Only works with `Option`s that contain a single value.
]=]
function Option.unwrapOrNil(self)
	return self[1]
end

--[=[
  Returns the result of the given function wrapped in an `Option` if
  the option is `Some`, otherwise returns `None`.
]=]
function Option.map(self, f)
	if self._n == 0 then
		return Option.None
	end
	return Option.Some(f(unpack(self :: any)))
end

--[=[
  Returns the result of the given function if the option is `Some`,
  otherwise returns the given default value.
]=]
function Option.mapOr(self, default, f)
	if self._n == 0 then
		return default
	end
	return f(unpack(self :: any))
end

--[=[
	Returns the result of the given function if the option is `Some`,
	otherwise returns the rest of the arguments.
]=]
function Option.mapOrRest(self, f, ...)
	if self._n == 0 then
		return ...
	end
	return f(unpack(self :: any))
end

--[=[
  Returns the result of the given function if the option is `Some`,
  otherwise returns the result of calling the default function.
]=]
function Option.mapOrElse(self, default, f)
	if self._n == 0 then
		return default()
	end
	return f(unpack(self :: any))
end

--[=[
  Returns `None` if the option is `None`, otherwise returns the other option.
]=]
function Option.andOpt(self, other)
	if self._n == 0 then
		return Option.None
	end
	return other
end

--[=[
  Returns `None` if the option is `None`, otherwise calls the given
  function with the value of the option and returns the result.
]=]
function Option.andThen(self, f)
	if self._n == 0 then
		return Option.None
	end
	return f(unpack(self :: any))
end

--[=[
  Returns `None` if the option is `None`, otherwise calls the given
  function with the value:
   - if the function returns `true`, returns the original option
   - if the function returns `false`, returns `None`
]=]
function Option.filter(self, f)
	if self._n == 0 then
		return Option.None
	end
	if f(unpack(self :: any)) then
		return self
	end
	return Option.None
end

--[=[
  Returns the option if it is `Some`, otherwise returns
  the other option.
]=]
function Option.orOpt(self, other)
	if self._n ~= 0 then
		return self
	end
	return other
end

--[=[
  Returns the option if it is `Some`, otherwise returns
  the result of calling the given function.
]=]
function Option.orElse(self, f)
	if self._n ~= 0 then
		return self
	end
	return f()
end

--[=[
  Returns `Some` if exactly one of the options is `Some`, otherwise
  returns `None`.
]=]
function Option.xor(self, other)
	if self._n == 0 then
		return other
	end
	if other._n == 0 then
		return self
	end
	return Option.None
end

--[=[
	Takes a table containing a `Some` and `None` function. If the option
	is a `Some`, calls the `Some` function with the value of the option,
	otherwise calls the `None` function. The result of the function call
	is returned.
]=]
function Option.match(self, f)
	if self._n ~= 0 then
		return f.Some(unpack(self :: any))
	end
	return f.None()
end

Option.join = function(self, other)
	if self._n == 0 or other._n == 0 then
		return Option.None
	end
	return Option.Some(unpack(self), unpack(other))
end :: any
do	-- use `stdio.format` on Lune which pretty-prints tables

	

local stdio = require("@lune/stdio")

	function Option.__tostring(self)
		if self._n ~= 0 then
			local s = ""
			for i = 1, self._n do
				if i > 1 then
					s ..= ", "
				end

				local v = self[i]
				if typeof(v) == "string" then
					s ..= string.format("%q", v)
				else
					s ..= stdio.format(v)
				end
			end

			return `Option::Some({s})`
		else
			return "Option::None"
		end
	end
end
--[=[
	Returns `true` if the given value is an `Option` and contains the
	same value as this option, `false` otherwise.
]=]























function Option.__eq(self, other)
	if Option.is(other) then
		if self._n == 0 and other._n == 0 then
			return true
		elseif self._n == 1 and other._n == 1 then
			return self[1] == other[1]
		elseif self._n == other._n then
			for i = 1, self._n do
				if self[i] ~= other[i] then
					return false
				end
			end
			return true
		end
	end
	return false
end

return Option
