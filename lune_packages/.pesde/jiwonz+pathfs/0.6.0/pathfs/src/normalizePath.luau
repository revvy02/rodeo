local types = require("./types")
local luauPath = require("../luau_packages/luau_path")
local Path = luauPath.Path

type Component = types.Component
type Components = types.Components
type AsPath = luauPath.AsPath
type Path = luauPath.Path

export type PeekableComponents = typeof(setmetatable(
	{} :: {
		iter: Components,
		peeked: Component | false,
	},
	{} :: PeekableComponentsImpl
))

type PeekableComponentsImpl = {
	__index: PeekableComponentsImpl,
	peek: (self: PeekableComponents) -> Component?,
	next: (self: PeekableComponents) -> Component?,
}

local PeekableComponents = {} :: PeekableComponentsImpl
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

local function peekable(iter: Components): PeekableComponents
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
return function(path: AsPath): Path
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
