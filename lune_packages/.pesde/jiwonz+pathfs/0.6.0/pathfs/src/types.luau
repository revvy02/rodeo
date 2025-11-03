local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path
local gt = require("../luau_packages/greentea")

export type Components = typeof(Path.new(""):components())

local PathType = gt.build(gt.custom(luauPath.Path.is, "Path") :: luauPath.Path)
local Components = getmetatable(Path.from("a"):components() :: any).__index :: Components & {
	new: (path: string, prefix: any?, hasPhysicalRoot: boolean) -> Components,
	is: (value: unknown) -> boolean,
}
local ComponentsType = gt.build(gt.custom(Components.is, "Components") :: Components)
local AsPathType = gt.build(gt.union(gt.string(), PathType:type(), ComponentsType:type()))
local ContentsType = gt.build(gt.union(gt.string(), gt.buffer()))
local booleanType = gt.build(gt.boolean())
local stringType = gt.build(gt.string())
local optionalBooleanType = gt.build(gt.opt(gt.boolean()))
local arrayOfStringType = gt.build(gt.array(gt.string()))

export type Component = typeof(Path.new(""):components():collect()[1])

export type Contents = typeof(ContentsType:type())

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
