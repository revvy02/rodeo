-- UUID generation for execution IDs

local uuid = {}

function uuid.generate(): string
	local bytes = {}
	for i = 1, 16 do
		bytes[i] = string.format("%02x", math.random(0, 255))
	end
	return "rir3-" .. table.concat(bytes)
end

return uuid
