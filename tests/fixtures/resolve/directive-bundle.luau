-- @rodeo run
local io = require("@rodeo/io")
local stream = require("@rodeo/stream")
stream.write(io.stdout, "directive_ok\n")
return "directive_ok"
