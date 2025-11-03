local String = require("../../utils/string")

local Option = require("../../../lune_packages/option")
type Option<T> = Option.Option<T>

local function charWordSep(char: string)
	return char == " " or char == "-" or char == "_"
end

return function<T>(str: string, substrings: { [T]: { string } }, fullWords: { [T]: { string } }): Option<T>
	local lowercased = string.lower(str)

	-- Look for substring matches
	for item: T, keywords in substrings do
		for _, keyword in keywords do
			if string.find(lowercased, keyword) then
				return Option.Some(item) :: Option<T>
			end
		end
	end

	-- If no substring matches found, look for a full word as a component
	local components = String.splitAtChar(lowercased, charWordSep)
	for _, component in components do
		for item, keywords in fullWords do
			for _, keyword in keywords do
				if string.find(component, keyword) then
					return Option.Some(item) :: Option<T>
				end
			end
		end
	end

	return Option.None :: Option<T>
end
