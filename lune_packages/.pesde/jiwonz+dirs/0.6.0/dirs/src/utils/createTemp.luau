-- Implementation based on https://github.com/Stebalien/tempfile/blob/6e995724c10bc9c5f524df2575c8f3fe1a7df875/src/util.rs

local pathfs = require("../../lune_packages/pathfs")
local fs = pathfs.fs
local tempDir = require("./tempDir")

local NUM_RETRIES = bit32.lshift(1, 31)
local NUM_RAND_CHARS = 6
local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

local function randomAlphanumeric(length: number): string
	local res = {}
	for i = 1, length do
		local choice = math.random(1, #CHARS)
		res[i] = CHARS:sub(choice, choice)
	end
	return table.concat(res)
end

local function tmpname(prefix: string, suffix: string, randomLength: number): string
	local buf = table.create(3)
	table.insert(buf, prefix)
	table.insert(buf, randomAlphanumeric(randomLength))
	table.insert(buf, suffix)
	return table.concat(buf)
end

local function writeBlankFile(path: pathfs.AsPath)
	fs.writeFile(path, "")
end

return function(
	isDir: boolean,
	base: pathfs.AsPath?,
	prefix: string?,
	suffix: string?,
	randomLength: number?
): pathfs.Path
	-- selene: allow(shadowing)
	local base = pathfs.Path.from(base or tempDir())
	-- selene: allow(shadowing)
	local prefix = prefix or ".tmp"
	-- selene: allow(shadowing)
	local suffix = suffix or ""
	-- selene: allow(shadowing)
	local randomLength = randomLength or NUM_RAND_CHARS

	local numRetries = if randomLength ~= 0 then NUM_RETRIES else 1
	local checkTemp = (if isDir then fs.isDir else fs.isFile) :: typeof(fs.isDir)
	local writeTemp = (if isDir then fs.writeDir else writeBlankFile) :: typeof(fs.writeDir)

	for _ = 0, numRetries do
		local path = base:join(tmpname(prefix, suffix, randomLength))
		if checkTemp(path) and numRetries > 1 then
			continue
		else
			local success = pcall(writeTemp, path)
			if success then
				return path
			elseif numRetries > 1 then
				continue
			end
		end
	end

	error("too many temporary files exist")
end
