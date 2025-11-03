local String = {}

function String.splitAt(str: string, pos: number): { string }?
	local left, right = string.sub(str, 1, pos - 1), string.sub(str, pos + 1)

	if left == nil or right == nil then
		return nil
	end

	return { left, right }
end

function String.splitAtChar(str: string, char: string | number | (c: string) -> boolean): { string }
	local strChars = string.split(str, "")
	local splitsPositions: { number } = {}

	for pos, strChar in strChars do
		local innerChar = if typeof(char) == "number"
			then string.char(char)
			elseif typeof(char) == "function" then char(strChar)
			elseif typeof(char) == "string" and #char == 1 then char
			else error(`Expected char, got {typeof(char)}`)

		if innerChar == true or strChar == innerChar then
			table.insert(splitsPositions, pos)
		end
	end

	local splitted: { string } = {}
	for idx, splitPos in splitsPositions do
		local previous = splitted[#splitted]
		local relativeSplit = if previous
			then String.splitAt(previous, splitPos - splitsPositions[idx - 1])
			else String.splitAt(str, splitPos)

		for _, split in assert(relativeSplit) do
			table.insert(splitted, split)
		end
	end

	local result = {}
	for idx, split in splitted do
		if idx % 2 ~= 0 or idx == #splitted or idx == #splitted - 1 then
			table.insert(result, split)
		end
	end

	return result
end

return String
