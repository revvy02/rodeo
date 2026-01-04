-- JSON to Luau table converter
-- Based on https://github.com/DervexDev/json2lua (MIT license)

local serde = require("@lune/serde")

-- Escape special characters in strings
local function escapeString(str: string): string
	local result = str
	result = result:gsub("\\", "\\\\") -- must be first
	result = result:gsub("\n", "\\n")
	result = result:gsub("\t", "\\t")
	result = result:gsub("\r", "\\r")
	result = result:gsub('"', '\\"')
	return result
end

-- Generate indentation
local function getIndent(depth: number): string
	return string.rep("\t", depth)
end

-- Check if table is an array (sequential integer keys starting at 1)
local function isArray(t: { [any]: any }): boolean
	local count = 0
	for _ in t do
		count += 1
	end
	for i = 1, count do
		if t[i] == nil then
			return false
		end
	end
	return true
end

-- Get sorted keys from a table for deterministic iteration
local function getSortedKeys(t: { [any]: any }): { string }
	local keys = {}
	for k in t do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	return keys
end

-- Recursive walk function
local function walk(key: string?, value: any, depth: number): string
	local lua = getIndent(depth)

	if key then
		lua ..= `["{escapeString(key)}"] = `
	end

	local valueType = typeof(value)

	if valueType == "string" then
		lua ..= `"{escapeString(value)}"`
	elseif valueType == "number" then
		lua ..= tostring(value)
	elseif valueType == "boolean" then
		lua ..= tostring(value)
	elseif value == nil then
		lua ..= "nil"
	elseif valueType == "table" then
		lua ..= "{\n"
		if isArray(value) then
			for _, v in ipairs(value) do
				lua ..= walk(nil, v, depth + 1)
			end
		else
			-- Sort keys for deterministic output
			local keys = getSortedKeys(value)
			for _, k in ipairs(keys) do
				lua ..= walk(k, value[k], depth + 1)
			end
		end
		lua ..= getIndent(depth) .. "}"
	end

	lua ..= ",\n"
	return lua
end

-- Main parse function: JSON string -> Luau table syntax string
local function parse(json: string): string
	local value = serde.decode("json", json)

	local lua = "return {\n"

	if typeof(value) == "table" then
		if isArray(value) then
			for _, v in ipairs(value) do
				lua ..= walk(nil, v, 1)
			end
		else
			-- Sort keys for deterministic output
			local keys = getSortedKeys(value)
			for _, k in ipairs(keys) do
				lua ..= walk(k, value[k], 1)
			end
		end
	end

	lua ..= "}\n"
	return lua
end

return { parse = parse }
