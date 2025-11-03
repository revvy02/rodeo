local function copy<T>(tab: T): T
	if typeof(tab) == "table" then
		local copied = {}

		for k, v in tab do
			copied[k] = copy(v)
		end

		return copied :: any
	end

	return tab
end

return copy
