local process = require("@lune/process")
local stdio = require("@lune/stdio")
stdio.write("lune_shim_ok\n")
return "cwd:" .. process.cwd
