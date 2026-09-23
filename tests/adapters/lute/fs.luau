-- @lute/fs conformance, per submodules/lute/definitions/fs.luau.
local fs = require("@lute/fs")

local function check(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

-- write/read round-trip through handles
local h = fs.open("lute-fs-test.txt", "w")
fs.write(h, "hello lute")
fs.close(h)
local h2 = fs.open("lute-fs-test.txt", "r")
check(fs.read(h2) == "hello lute", "read round-trip failed")
fs.close(h2)

-- buffer contents are accepted and binary-safe
local blob = buffer.create(256)
for i = 0, 255 do
	buffer.writeu8(blob, i, i)
end
local hb = fs.open("lute-fs-bin.bin", "w")
fs.write(hb, blob)
fs.close(hb)
local hb2 = fs.open("lute-fs-bin.bin", "r")
local back = fs.read(hb2)
fs.close(hb2)
check(back == buffer.tostring(blob), "binary round-trip failed")

-- readIntoBuffer window
local target = buffer.create(16)
local hr = fs.open("lute-fs-bin.bin", "r")
local n = fs.readIntoBuffer(hr, target, 10, 16)
fs.close(hr)
check(n == 16, `readIntoBuffer returned {n}, expected 16`)
check(buffer.readu8(target, 0) == 10, "readIntoBuffer window content wrong")

-- exclusive create
local ok = pcall(fs.open, "lute-fs-test.txt", "x")
check(not ok, "mode 'x' on an existing file should error")

-- type / exists / stat
check(fs.type("lute-fs-test.txt") == "file", "type(file) wrong")
check(fs.exists("lute-fs-test.txt"), "exists(file) wrong")
check(not fs.exists("lute-fs-missing-xyz"), "exists(missing) wrong")
check(fs.type("lute-fs-missing-xyz") == "unknown", "type(missing) should be 'unknown'")
local meta = fs.stat("lute-fs-test.txt")
check(meta.type == "file", "stat.type wrong")
check(meta.size == 10 or meta.size == "10", "stat.size wrong")
check(meta.modified:toSeconds() > 1e9, "stat.modified is not an epoch Duration")
check(meta.modified >= meta.created, "modified precedes created")

-- dirs: mkdir (recursive), listdir, copy (recursive), move, rmdir (recursive)
fs.mkdir("lute-fs-dir/nested")
check(fs.type("lute-fs-dir") == "dir", "type(dir) wrong")
local hd = fs.open("lute-fs-dir/nested/inner.txt", "w")
fs.write(hd, "inner")
fs.close(hd)
local entries = fs.listdir("lute-fs-dir")
check(#entries == 1 and entries[1].name == "nested" and entries[1].type == "dir", "listdir entry wrong")
fs.copy("lute-fs-dir", "lute-fs-dir2")
check(fs.exists("lute-fs-dir2/nested/inner.txt"), "recursive copy lost a file")
fs.move("lute-fs-dir2", "lute-fs-dir3")
check(not fs.exists("lute-fs-dir2") and fs.exists("lute-fs-dir3/nested/inner.txt"), "move failed")
fs.rmdir("lute-fs-dir")
fs.rmdir("lute-fs-dir3")
check(not fs.exists("lute-fs-dir"), "rmdir left the tree")

-- unsupported surface errors clearly instead of misbehaving
for _, fn in { fs.link, fs.symlink } do
	local okUnsupported, err = pcall(fn, "a", "b")
	check(not okUnsupported and tostring(err):find("not supported") ~= nil, "unsupported fn should error clearly")
end

fs.remove("lute-fs-test.txt")
fs.remove("lute-fs-bin.bin")
return true
