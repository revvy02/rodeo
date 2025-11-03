local pathfs = require("../../lune_packages/pathfs")
local process = require("@lune/process")

--[=[
Converts win paths including env path into Path object

ex. "%APPDATA%\\Something" -> Path({process.env.APPDATA, "Something"})
]=]
return function(path: string): pathfs.Path?
	local p = pathfs.Path.from(path)
	local components = p:components()
	local newPath

	for _, v in components:collect() do
		local s = v:toString()
		if s:sub(1, 1) == "%" and s:sub(-1) == "%" then
			local var = s:sub(2, -2)
			local envPath = process.env[var]
			if envPath then
				s = envPath
			end
		end
		if newPath then
			newPath:push(s)
		else
			newPath = pathfs.Path.from(s)
		end
	end

	return newPath
end
