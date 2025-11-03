local process = require("@lune/process")

local targetOS = process.os

local function getTempDir(): string?
	local dir = process.env.TMPDIR or process.env.TMP or process.env.TEMP

	if not dir or dir == "" then
		return nil
	end

	if #dir > 1 and dir:sub(-1) == "/" then
		dir = dir:sub(1, -2)
	end

	return dir
end

return function()
	if targetOS == "windows" then
		local path = process.env.TEMP or process.env.TMP or (process.env.SystemRoot or process.env.windir) .. "\\temp"

		if #path > 1 and path[#path - 1] == "\\" and path[#path - 2] ~= ":" then
			return path:sub(1, -1)
		end

		return path
	end

	return getTempDir() or "/tmp"
end
