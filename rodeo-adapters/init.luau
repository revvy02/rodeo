local lune = require("@self/lune/map")

local adapters = {}
for alias, modules in lune do
	adapters[alias] = modules
end
return adapters
