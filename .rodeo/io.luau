--!nocheck

local fs = require("@rodeo/fs")
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")

local function check(cond, msg)
	if not cond then
		error(msg or "check failed", 2)
	end
end

-- stdout write
stream.write(io.stdout, "hello from io test\n")

-- stderr write
stream.write(io.stderr, "stderr test\n")

-- file io round-trip via fs.open + stream
local f = fs.open("rodeo-test-io-roundtrip.txt", "w")
stream.write(f, "line one\n")
stream.write(f, "line two\n")
stream.close(f)

local f2 = fs.open("rodeo-test-io-roundtrip.txt", "r")
local contents = stream.read(f2)
stream.close(f2)
check(contents == "line one\nline two\n", "file round-trip")

-- cleanup
fs.remove("rodeo-test-io-roundtrip.txt")

-- stdin read (pipe input via: echo "test input" | rodeo run io)
stream.write(io.stdout, "enter something: ")
local input = stream.read(io.stdin)
stream.write(io.stdout, "you said: " .. tostring(input) .. "\n")

-- stdout write after close is fine (close is no-op for std streams)
stream.close(io.stdout)
stream.write(io.stdout, "after close\n")
