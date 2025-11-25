-- Build script for creating self-contained rodeo binaries
-- Embeds plugin binary as a global variable in the bundled code

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

-- Platform targets for cross-compilation
local TARGETS = {
	{ os = "macos", arch = "aarch64", ext = "" },
	{ os = "macos", arch = "x86_64", ext = "" },
	{ os = "linux", arch = "x86_64", ext = "" },
	{ os = "windows", arch = "x86_64", ext = ".exe" },
}

local function log(message: string)
	stdio.write(`[build] {message}\n`)
end

local function runCommand(command: string, args: { string }, description: string): boolean
	log(description)
	local result = process.exec(command, args)

	if not result.ok then
		stdio.ewrite(`Error: {description} failed\n`)
		if result.stderr and #result.stderr > 0 then
			stdio.ewrite(`{result.stderr}\n`)
		end
		return false
	end

	return true
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function main()
	log("Starting rodeo binary build process...")

	-- Clean build directory first to avoid stale artifacts
	if fs.isDir("build") then
		fs.removeDir("build")
	end

	-- Step 1: Build plugin with Rojo
	log("Step 1/5: Building plugin with Rojo")

	ensureDir("build")

	local pluginSuccess = runCommand("rojo", { "build", "plugin/plugin.project.json", "-o", "build/plugin.rbxmx" }, "Building plugin")

	if not pluginSuccess then
		process.exit(1)
	end

	-- Step 2: Read plugin binary as raw string
	log("Step 2/5: Reading plugin binary")

	local pluginBinary = fs.readFile("build/plugin.rbxmx")

	log(`  Plugin: {#pluginBinary} bytes`)

	-- Step 3: Patch darklua config with injected global
	log("Step 3/5: Patching darklua config with embedded plugin")

	local templateConfig = fs.readFile(".lune/bundle.darklua.json")
	local config = serde.decode("json", templateConfig)

	-- Add inject_global_value rule with raw binary string
	table.insert(config.rules, {
		rule = "inject_global_value",
		identifier = "RODEO_PLUGIN",
		value = pluginBinary,
	})

	-- Write patched config
	local patchedConfig = serde.encode("json", config)
	fs.writeFile("build/bundle.darklua.json.patched", patchedConfig)

	-- Step 4: Bundle source with darklua
	log("Step 4/5: Bundling source with darklua")

	local bundleSuccess = runCommand("darklua", { "process", "src", "build/bundle", "--config", "build/bundle.darklua.json.patched" }, "Running darklua bundler")

	if not bundleSuccess then
		process.exit(1)
	end

	-- Step 5: Build binaries for each platform
	log("Step 5/5: Building platform-specific binaries")

	ensureDir("build/releases")

	for _, target in TARGETS do
		local platformName = `{target.os}-{target.arch}`
		local outputPath = `build/releases/rodeo_{platformName}{target.ext}`
		local targetArg = `{target.os}-{target.arch}`

		local buildSuccess = runCommand("lune", { "build", "build/bundle/init.luau", "-o", outputPath, "--target", targetArg }, `Building for {platformName}`)

		if not buildSuccess then
			stdio.ewrite(`Warning: Failed to build for {platformName}, continuing...\n`)
		else
			local fileSize = #fs.readFile(outputPath)
			log(`  Created {outputPath} ({fileSize} bytes)`)
		end
	end

	log("Build complete! Binaries are in build/releases/")
end

main()
