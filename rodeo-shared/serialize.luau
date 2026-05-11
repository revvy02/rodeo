-- Luau table serializer: converts normalized values to Luau source code
-- Returns the serializeToLuau function

local function escapeString(str)
	local r = str
	r = r:gsub("\\", "\\\\")
	r = r:gsub("\n", "\\n")
	r = r:gsub("\t", "\\t")
	r = r:gsub("\r", "\\r")
	r = r:gsub('"', '\\"')
	return r
end

local function getIndent(depth)
	return string.rep("\t", depth)
end

local function isArray(t)
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

local function getSortedKeys(t)
	local keys = {}
	for k in t do
		table.insert(keys, tostring(k))
	end
	table.sort(keys)
	return keys
end

-- Luau constructor emitters for tagged type structs
local TYPE_EMITTERS = {
	Vector3 = function(v)
		return "vector.create(" .. table.concat(v, ", ") .. ")"
	end,
	Vector2 = function(v)
		return "Vector2.new(" .. table.concat(v, ", ") .. ")"
	end,
	CFrame = function(v)
		return "CFrame.new(" .. table.concat(v, ", ") .. ")"
	end,
	Color3 = function(v)
		return "Color3.new(" .. table.concat(v, ", ") .. ")"
	end,
	UDim = function(v)
		return "UDim.new(" .. table.concat(v, ", ") .. ")"
	end,
	UDim2 = function(v)
		return "UDim2.new(" .. table.concat(v, ", ") .. ")"
	end,
	NumberRange = function(v)
		return "NumberRange.new(" .. table.concat(v, ", ") .. ")"
	end,
	Rect = function(v)
		return "Rect.new(" .. table.concat(v, ", ") .. ")"
	end,
}

local function walk(key, value, depth)
	local lua = getIndent(depth)
	if key then
		lua = lua .. '["' .. escapeString(key) .. '"] = '
	end
	local valueType = typeof(value)
	if valueType == "string" then
		lua = lua .. '"' .. escapeString(value) .. '"'
	elseif valueType == "number" then
		lua = lua .. tostring(value)
	elseif valueType == "boolean" then
		lua = lua .. tostring(value)
	elseif value == nil then
		lua = lua .. "nil"
	elseif valueType == "table" then
		-- Check for tagged Roblox type struct
		local taggedType = value.type
		local emitter = taggedType and TYPE_EMITTERS[taggedType]
		if emitter then
			lua = lua .. emitter(value.value)
		else
			lua = lua .. "{\n"
			if isArray(value) then
				for _, v in ipairs(value) do
					lua = lua .. walk(nil, v, depth + 1)
				end
			else
				local keys = getSortedKeys(value)
				for _, k in ipairs(keys) do
					lua = lua .. walk(k, value[k], depth + 1)
				end
			end
			lua = lua .. getIndent(depth) .. "}"
		end
	end
	lua = lua .. ",\n"
	return lua
end

local function serializeToLuau(value)
	local lua = "return {\n"
	if typeof(value) == "table" then
		if isArray(value) then
			for _, v in ipairs(value) do
				lua = lua .. walk(nil, v, 1)
			end
		else
			local keys = getSortedKeys(value)
			for _, k in ipairs(keys) do
				lua = lua .. walk(k, value[k], 1)
			end
		end
	end
	lua = lua .. "}\n"
	return lua
end

return serializeToLuau
