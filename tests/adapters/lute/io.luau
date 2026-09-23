-- @lute/io conformance, per submodules/lute/definitions/io.luau.
-- write goes to stdout (asserted by the harness on captured output);
-- read needs interactive stdin, which a rodeo run doesn't have, so only its
-- presence is checked.
local io = require("@lute/io")

assert(type(io.write) == "function", "io.write missing")
assert(type(io.read) == "function", "io.read missing")

io.write("lute-io-", "multi-arg", "\n")

return true
