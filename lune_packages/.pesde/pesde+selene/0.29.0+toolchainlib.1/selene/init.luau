local process = require("@lune/process")

local exitCode = require("@self/lune_packages/toolchainlib")("Kampfkarren/selene", _G.PESDE_ROOT)

return process.exit(exitCode)
