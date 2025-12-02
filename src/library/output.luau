-- Output utilities for formatted terminal printing

local chalk = require("@pkg/chalk")
local config = require("./config")

local function formatBitset(bitsetValue: number, filterMask: number?): string
	local parts = {}
	local contextOrder = {
		{ name = "studio", bit = config.CONTEXT_BITS.isStudio },
		{ name = "server", bit = config.CONTEXT_BITS.isServer },
		{ name = "client", bit = config.CONTEXT_BITS.isClient },
		{ name = "edit", bit = config.CONTEXT_BITS.isEdit },
		{ name = "running", bit = config.CONTEXT_BITS.isRunning },
	}

	for _, context in ipairs(contextOrder) do
		local bitMask = bit32.lshift(1, context.bit)
		local isSet = bit32.band(bitsetValue, bitMask) ~= 0

		-- Only include if no filter mask, or if filter mask includes this bit
		if not filterMask or bit32.band(filterMask, bitMask) ~= 0 then
			local colorFn = isSet and chalk.green or chalk.red
			local bitValue = isSet and "1" or "0"
			table.insert(parts, chalk.grey(context.name .. ":") .. " " .. colorFn(bitValue))
		end
	end

	return table.concat(parts, ", ")
end

local function formatBitsetShort(bitset: number): string
	local bits = {
		bit32.band(bit32.rshift(bitset, config.CONTEXT_BITS.isStudio), 1),
		bit32.band(bit32.rshift(bitset, config.CONTEXT_BITS.isServer), 1),
		bit32.band(bit32.rshift(bitset, config.CONTEXT_BITS.isClient), 1),
		bit32.band(bit32.rshift(bitset, config.CONTEXT_BITS.isEdit), 1),
		bit32.band(bit32.rshift(bitset, config.CONTEXT_BITS.isRunning), 1),
	}

	local parts = {}
	for _, bit in ipairs(bits) do
		local colorFn = bit == 1 and chalk.green or chalk.red
		table.insert(parts, colorFn(tostring(bit)))
	end

	return table.concat(parts, "")
end

local function formatShortLog(studioId: string, bitset: number, executionId: string?): string
	local shortId = studioId:sub(1, 8)
	local bitsetShort = formatBitsetShort(bitset)

	if executionId then
		local execShort = executionId:sub(6, 13) -- Skip "rodeo-" prefix
		return chalk.grey("[id:") .. " " .. shortId .. chalk.grey("] [") .. bitsetShort .. chalk.grey("]") .. " " .. execShort
	else
		return chalk.grey("[id:") .. " " .. shortId .. chalk.grey("] [") .. bitsetShort .. chalk.grey("]")
	end
end

return {
	formatBitset = formatBitset,
	formatBitsetShort = formatBitsetShort,
	formatShortLog = formatShortLog,
}
