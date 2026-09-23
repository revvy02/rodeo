local io = require("@rodeo/io")
local stream = require("@rodeo/stream")
local helper = require("./helper")
local process = require("@lune/process")
stream.write(io.stdout, "mixed:" .. helper.value .. ":" .. process.cwd .. "\n")
return "mixed_ok"
