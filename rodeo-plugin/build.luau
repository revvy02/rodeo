-- Build the rodeo plugin (.rbxm).
-- Runs rojo sourcemap → darklua process → assemble bundle → rojo build.
-- Invoked from repo root (cwd = repo root) by the top-level build script:
--   lune run rodeo-plugin/build
-- Also self-runnable for plugin-only rebuilds.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local OUT_DIR = "rodeo-plugin/build"
local BUNDLE_DIR = OUT_DIR .. "/plugin_bundle"

-- Read CLI version (single source of truth for plugin's RODEO_VERSION global)
local cargoToml = serde.decode("toml", fs.readFile("rodeo-cli/Cargo.toml"))
local version = cargoToml.package.version
print(`Plugin build: version {version}`)

-- Clean prior artifacts
if fs.isDir(OUT_DIR) then
	fs.removeDir(OUT_DIR)
end

-- rojo sourcemap (darklua's convert_require needs it)
print("Generating plugin sourcemap...")
process.exec("rojo", {
	"sourcemap",
	"rodeo-plugin/default.project.json",
	"-o",
	"rodeo-plugin/sourcemap.json",
}, { stdio = "forward" })

-- darklua: require conversion + version injection
print("Processing plugin source...")
process.exec("darklua", {
	"process",
	"rodeo-plugin/src",
	BUNDLE_DIR .. "/src",
	"--config",
	"rodeo-plugin/.darklua.json",
}, { stdio = "forward", env = { RODEO_VERSION = version } })

-- Assemble bundle tree
fs.copy("rodeo-plugin/roblox_packages", BUNDLE_DIR .. "/roblox_packages")
fs.copy("rodeo-pkg/rodeo/src", BUNDLE_DIR .. "/rodeo_pkg_src")
fs.copy("rodeo-shared/proto", BUNDLE_DIR .. "/proto_luau")

-- Bundle-local rojo project. Sibling paths (./X) stay the same because the
-- project file lives inside plugin_bundle/ alongside its children. The
-- `shared` link reaches one extra level up since the bundle dir moved from
-- build/plugin_bundle/ (2 levels up to repo root) to
-- rodeo-plugin/build/plugin_bundle/ (3 levels up).
fs.writeFile(
	BUNDLE_DIR .. "/default.project.json",
	serde.encode("json", {
		name = "rodeo_plugin",
		tree = {
			["$className"] = "Folder",
			plugin = {
				["$path"] = "./src",
			},
			packages = {
				["$path"] = "./roblox_packages",
				rodeo = {
					["$path"] = "./rodeo_pkg_src",
				},
			},
			proto = {
				["$path"] = "./proto_luau",
			},
			shared = {
				["$path"] = "../../../rodeo-shared",
			},
		},
	})
)

-- Build final .rbxm
print("Building plugin binary...")
process.exec("rojo", {
	"build",
	BUNDLE_DIR .. "/default.project.json",
	"-o",
	OUT_DIR .. "/plugin.rbxm",
}, { stdio = "forward" })

print("Plugin build complete.")
