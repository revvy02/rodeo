local fs = require("@rodeo/fs")
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")
stream.write(io.stdout, "resolved\n")
return "alias_ok"
