-- Pure-Luau base64 decode. Only `decode` is needed (fileChunk accumulation);
-- `encode` can be added when an outbound binary payload appears.

local base64 = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local INDEX: { [string]: number } = {}
for i = 1, #ALPHABET do
	INDEX[string.sub(ALPHABET, i, i)] = i - 1
end

-- Decodes a base64 string into a buffer. Ignores whitespace; accepts '=' padding.
function base64.decode(input: string): buffer
	local clean = string.gsub(input, "%s", "")
	clean = string.gsub(clean, "=+$", "")
	local inLen = #clean
	local outLen = math.floor(inLen * 3 / 4)
	local buf = buffer.create(outLen)

	local pos = 0
	local i = 1
	while i <= inLen do
		local c1 = INDEX[string.sub(clean, i, i)] or 0
		local c2 = INDEX[string.sub(clean, i + 1, i + 1)] or 0
		local c3 = INDEX[string.sub(clean, i + 2, i + 2)] or 0
		local c4 = INDEX[string.sub(clean, i + 3, i + 3)] or 0

		local triple = bit32.bor(bit32.lshift(c1, 18), bit32.lshift(c2, 12), bit32.lshift(c3, 6), c4)

		if pos < outLen then
			buffer.writeu8(buf, pos, bit32.band(bit32.rshift(triple, 16), 0xff))
			pos += 1
		end
		if pos < outLen then
			buffer.writeu8(buf, pos, bit32.band(bit32.rshift(triple, 8), 0xff))
			pos += 1
		end
		if pos < outLen then
			buffer.writeu8(buf, pos, bit32.band(triple, 0xff))
			pos += 1
		end
		i += 4
	end

	return buf
end

return base64
