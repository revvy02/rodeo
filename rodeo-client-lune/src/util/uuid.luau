-- RFC 4122 version 4 UUID. Used for JSON-RPC request ids (as strings) and
-- streamIds. Quality of randomness matches math.random (lune seeds from OS).

local uuid = {}

local HEX = "0123456789abcdef"

local function randHex(n: number): string
	local out = table.create(n)
	for i = 1, n do
		local k = math.random(1, 16)
		out[i] = string.sub(HEX, k, k)
	end
	return table.concat(out)
end

function uuid.v4(): string
	local a = randHex(8)
	local b = randHex(4)
	local c = "4" .. randHex(3)
	local vi = math.random(1, 4)
	local variant = string.sub("89ab", vi, vi)
	local d = variant .. randHex(3)
	local e = randHex(12)
	return `{a}-{b}-{c}-{d}-{e}`
end

return uuid
