-- @lune/fs shim — maps to rodeo's fs + stream RPCs
local g = _G.__rodeo_procs[_G.__rodeo_eid]

local function readFile(path: string): string
	local h = g.fs.open(path, "r")
	local content = g.stream.read(h)
	g.stream.close(h)
	return content or ""
end

local function writeFile(path: string, content: string)
	local h = g.fs.open(path, "w")
	g.stream.write(h, content)
	g.stream.close(h)
end

local function isFile(path: string): boolean
	local ok, result = pcall(g.fs.type, path)
	return ok and result == "file"
end

local function isDir(path: string): boolean
	local ok, result = pcall(g.fs.type, path)
	return ok and result == "directory"
end

local function readDir(path: string): { string }
	local entries = g.fs.listdir(path)
	local names = {}
	for _, entry in entries do
		table.insert(names, entry.name)
	end
	return names
end

local function removeFile(path: string)
	g.fs.remove(path)
end

local function removeDir(path: string)
	g.fs.rmdir(path)
end

local function writeDir(path: string)
	g.fs.mkdir(path)
end

local function copy(from: string, to: string)
	g.fs.copy(from, to)
end

local function move(from: string, to: string)
	g.fs.copy(from, to)
	g.fs.remove(from)
end

local function metadata(path: string)
	local stat = g.fs.stat(path)
	return {
		kind = if stat.type == "file" then "file" elseif stat.type == "directory" then "dir" else stat.type,
		permissions = stat.permissions,
		createdAt = stat.created,
		modifiedAt = stat.modified,
		accessedAt = stat.accessed,
	}
end

return {
	readFile = readFile,
	writeFile = writeFile,
	isFile = isFile,
	isDir = isDir,
	readDir = readDir,
	removeFile = removeFile,
	removeDir = removeDir,
	writeDir = writeDir,
	copy = copy,
	move = move,
	metadata = metadata,
}
