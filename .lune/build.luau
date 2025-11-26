-- Build script for creating self-contained rodeo binaries
-- Embeds plugin binary as a global variable in the bundled code

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

-- Platform targets for cross-compilation
local TARGETS = {
	{ os = "macos", arch = "aarch64", ext = "" },
	{ os = "macos", arch = "x86_64", ext = "" },
	{ os = "linux", arch = "x86_64", ext = "" },
	{ os = "windows", arch = "x86_64", ext = ".exe" },
}

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function main()
	if fs.isDir("build") then
		fs.removeDir("build")
	end

	ensureDir("build")

	-- Build plugin bundle, which needs sourcemap to exist first for darklua to work
	process.exec("rojo", {
		"sourcemap",
		"plugin/default.project.json",
		"-o",
		"plugin/sourcemap.json",
	}, { stdio = "forward" })

	process.exec("darklua", {
		"process",
		"plugin/src",
		"build/plugin_bundle/src",
		"--config",
		"plugin/.darklua.json",
	}, { stdio = "forward" })

	-- Copy roblox_packages to build directory
	fs.copy("plugin/roblox_packages", "build/plugin_bundle/roblox_packages")

	fs.writeFile(
		"build/plugin_bundle/default.project.json",
		serde.encode("json", {
			name = "rodeo_plugin",
			tree = {
				["$className"] = "Folder",
				plugin = {
					["$path"] = "./src",
				},
				packages = {
					["$path"] = "./roblox_packages",
				},
			},
		})
	)
	process.exec("rojo", { "build", "build/plugin_bundle/default.project.json", "-o", "build/plugin.rbxmx" }, { stdio = "forward" })

	-- Read plugin binary and create darklua config with embedded plugin
	local pluginBinary = fs.readFile("build/plugin.rbxmx")

	local templateConfig = fs.readFile(".darklua.json")
	local config = serde.decode("json", templateConfig)

	table.insert(config.rules, {
		rule = "inject_global_value",
		identifier = "RODEO_PLUGIN",
		value = pluginBinary,
	})

	fs.writeFile("build/release_bundle.darklua.json", serde.encode("json", config))

	process.exec("darklua", { "process", "src", "build/release_bundle", "--config", "build/release_bundle.darklua.json" }, { stdio = "forward" })

	ensureDir("build/releases")

	for _, target in TARGETS do
		local platformName = `{target.os}-{target.arch}`
		local outputPath = `build/releases/rodeo_{platformName}{target.ext}`
		local targetArg = `{target.os}-{target.arch}`

		process.exec("lune", { "build", "build/release_bundle/init.luau", "-o", outputPath, "--target", targetArg }, { stdio = "forward" })

		local fileSize = #fs.readFile(outputPath)
		print(`  Created {outputPath} ({fileSize} bytes)`)
	end

	print("Build complete! Binaries are in build/releases/")
end

main()
