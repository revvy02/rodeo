return function(tab)
	local len = #tab
	for pos = 1, len // 2 do
		tab[pos], tab[len - pos + 1] = tab[len - pos + 1], tab[pos]
	end
end
