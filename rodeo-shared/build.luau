-- Generate Luau proto bindings from rodeo-proto/proto/ into rodeo-shared/proto/.
-- Invoked from repo root (cwd = repo root):
--   lune run rodeo-shared/build
-- Also self-runnable for Luau-proto-only regen.

local fs = require("@lune/fs")
local process = require("@lune/process")

-- rodeo-shared/proto/ is 100% generated — wipe before regenerating
if fs.isDir("rodeo-shared/proto") then
	fs.removeDir("rodeo-shared/proto")
end
fs.writeDir("rodeo-shared/proto")

print("Generating Luau proto types...")
process.exec("protoc", {
	"--luau_out=rodeo-shared/proto",
	"--luau_opt=roblox_imports=false,field_name_case=camel",
	"--proto_path=rodeo-proto/proto",
	"rodeo-proto/proto/rodeo.proto",
	"rodeo-proto/proto/runtime.proto",
}, { stdio = "forward" })

print("Luau proto gen complete.")
