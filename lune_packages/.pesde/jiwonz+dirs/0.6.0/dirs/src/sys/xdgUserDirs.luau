local pathfs = require("../../lune_packages/pathfs")
local fs = pathfs.fs

local xdgUserDirs = {}

local function splitOnce(bytes: string, separator: string): (string?, string?)
	local prefix, suffix = bytes:match("(.-)%" .. separator .. "(.+)")
	return prefix, suffix
end

local function trimBlank(bytes: string): string
	return bytes:gsub("%s+", "")
end

local function startsWith(bytes: string, with: string)
	return bytes:sub(1, 1) == with
end

local function endsWith(bytes: string, with: string)
	return bytes:sub(-1) == with
end

local function shellUnescape(escaped: string): { string }
	local length = #escaped
	local unescaped = table.create(length)
	local i = 1

	while i <= length do
		local b = escaped:byte(i)

		if b == string.byte("\\") then
			i = i + 1
			if i <= length then
				table.insert(unescaped, escaped:sub(i, i))
			end
		else
			table.insert(unescaped, escaped:sub(i, i))
		end

		i = i + 1
	end

	return unescaped
end

local function parseUserDirs(homeDir: pathfs.Path, userDir: string?, bytes: string): { [string]: pathfs.Path }
	local userDirs = {}

	for _, line in bytes:split("\n") do
		local singleDirFound = false
		local key, value = splitOnce(line, "=")
		if not key or not value then
			continue
		end

		key = trimBlank(key)
		if startsWith(key, "XDG_") and endsWith(key, "_DIR") then
			local k = key:sub(5, key:len() - 4)
			if userDir == k then
				singleDirFound = true
				key = k
			elseif userDir == nil then
				key = k
			else
				continue
			end
		end

		value = trimBlank(value)
		if startsWith(value, '"') and endsWith(value, '"') then
			value = value:sub(2, value:len() - 1)
		else
			continue
		end

		local isRelative
		if value == "$HOME/" then
			continue
		elseif startsWith(value, "$HOME/") then
			value = value:sub(("$HOME/"):len())
			isRelative = true
		elseif startsWith(value, "/") then
			isRelative = false
		else
			continue
		end

		value = table.concat(shellUnescape(value))

		local path
		if isRelative then
			local p = pathfs.Path.from(homeDir)
			p:push(value)
			path = p
		else
			path = pathfs.Path.from(value)
		end

		userDirs[key] = path
		if singleDirFound then
			break
		end
	end

	return userDirs
end

function xdgUserDirs.all(homeDirPath: pathfs.Path, userDirFilePath: pathfs.Path): { [string]: pathfs.Path }
	local bytes = fs.readFile(userDirFilePath) or ""
	return parseUserDirs(homeDirPath, nil, bytes)
end

function xdgUserDirs.single(
	homeDirPath: pathfs.Path,
	userDirFilePath: pathfs.Path,
	userDirName: string
): { [string]: pathfs.Path }
	local bytes = fs.readFile(userDirFilePath) or ""
	return parseUserDirs(homeDirPath, userDirName, bytes)
end

return xdgUserDirs
