-- Type converters: Roblox types → JSON-compatible tagged structs
-- Returns the normalize function

local TYPE_CONVERTERS = {
	Vector3 = function(v)
		return { type = "Vector3", value = { v.X, v.Y, v.Z } }
	end,
	Vector2 = function(v)
		return { type = "Vector2", value = { v.X, v.Y } }
	end,
	CFrame = function(v)
		return { type = "CFrame", value = { v:GetComponents() } }
	end,
	Color3 = function(v)
		return { type = "Color3", value = { v.R, v.G, v.B } }
	end,
	UDim = function(v)
		return { type = "UDim", value = { v.Scale, v.Offset } }
	end,
	UDim2 = function(v)
		return { type = "UDim2", value = { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset } }
	end,
	NumberRange = function(v)
		return { type = "NumberRange", value = { v.Min, v.Max } }
	end,
	Rect = function(v)
		return { type = "Rect", value = { v.Min.X, v.Min.Y, v.Max.X, v.Max.Y } }
	end,
}

local function normalize(value)
	local t = typeof(value)
	local converter = TYPE_CONVERTERS[t]
	if converter then
		return converter(value)
	elseif t == "table" then
		local result = {}
		for k, v in pairs(value) do
			result[k] = normalize(v)
		end
		return result
	elseif t == "string" or t == "number" or t == "boolean" then
		return value
	elseif value == nil then
		return value
	else
		return tostring(value)
	end
end

return normalize
