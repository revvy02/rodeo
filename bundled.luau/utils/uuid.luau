-- UUID generation for execution IDs

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
