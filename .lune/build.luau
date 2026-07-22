-- Build script for rodeo
-- 1. Builds the Roblox Studio plugin (.rbxm)
-- 2. Builds the Rust CLI binary via cargo

local fs = require("@lune/fs")
local process = require("@lune/process")

-- Exec a subprocess, abort the build if it exits non-zero. The historical
-- bug: `process.exec` returns a result whose `.ok` is false on failure, but
-- nothing in this script was checking it — so a failing `cargo build` would
-- leave behind the previous successful binary at build/cargo/release/rodeo,
-- we'd copy THAT stale binary to bin/rodeo, and print "Build complete!".
-- Downstream tests then silently ran against code that never compiled.
local function exec(cmd: string, args: { string }, opts: any?)
	local result = process.exec(cmd, args, opts or { stdio = "forward" })
	if not result.ok then
		local joined = table.concat(args, " ")
		error(
			string.format("%s %s failed with exit code %d", cmd, joined, result.code),
			0
		)
	end
	return result
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function main()
	local isDev = table.find(process.args, "--dev") ~= nil

	ensureDir("build")

	-- Generate proto bindings (each language owned by its consumer subproject)
	exec("lune", { "run", "rodeo-shared/build" })
	exec("lune", { "run", "rodeo-client-ts/build" })

	-- Build plugin .rbxm (delegates to rodeo-plugin/build.luau; output lands at
	-- rodeo-plugin/build/plugin.rbxm)
	exec("lune", { "run", "rodeo-plugin/build" })

	-- Build Rust CLI binary
	-- Resolve cargo path: mise may provide it, otherwise fall back to ~/.cargo/bin
	local cargoPath = "cargo"
	local home = process.env.HOME or ""
	local localCargo = home .. "/.cargo/bin/cargo"
	if home ~= "" and fs.isFile(localCargo) then
		cargoPath = localCargo
	end

	local profile = if isDev then "debug" else "release"

	print(`Building Rust CLI ({profile})...`)
	local cargoArgs = { "build", "--manifest-path", "Cargo.toml" }
	if not isDev then
		table.insert(cargoArgs, "--release")
	end
	exec(cargoPath, cargoArgs, {
		stdio = "forward",
		env = { CARGO_TARGET_DIR = "build/cargo" },
	})

	-- Copy binary to bin/ for local use (mise prepends bin/ to PATH)
	local ext = if process.os == "windows" then ".exe" else ""
	local cargoBinary = `build/cargo/{profile}/rodeo{ext}`
	-- Preserve the extension on the destination too: on Windows an
	-- extensionless file isn't executable (PATHEXT), so `rodeo` on PATH and
	-- the `bin/rodeo` MCP server spawn both fail — Explorer even pops an
	-- "open with" dialog when something tries to ShellExecute it.
	local binTarget = `bin/rodeo{ext}`

	if fs.isFile(cargoBinary) then
		ensureDir("bin")
		if fs.isFile(binTarget) then
			fs.removeFile(binTarget)
		end
		fs.copy(cargoBinary, binTarget)
		print(`Copied binary to {binTarget}`)
	end

	-- launch-control helper is dispatched via rodeo's own __launch-control
	-- subcommand (see rodeo-cli/src/main.rs early dispatch + the
	-- set_helper_invocation call in async_main). No separate binary to
	-- deploy — single-binary distribution.

	print("Build complete!")
end

main()
