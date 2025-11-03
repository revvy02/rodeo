--> ENTRYPOINT; The main logic is as follows:
--> * First, we fetch the artifacts
--> * We try going through the list and using pattern matching to figure out
-->   which is the artifact to download
--> * If we get no matches, we try downloading all the artifacts
--> * The artifacts are all extracted and we try detecting the platform from
-->   binary data
--> * We then install the artifact with the matching platform descriptor

local net = require("@lune/net")
local process = require("@lune/process")
local stdio = require("@lune/stdio")
local serde = require("@lune/serde")
local task = require("@lune/task")

local pathfs = require("./lune_packages/pathfs")
local fs = pathfs.fs

local dirs = require("./lune_packages/dirs")

local Result = require("./lune_packages/result")
local ResultExt = require("@self/utils/ext/result")
local Option = require("./lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local Github = require("@self/github")
local descriptors = require("@self/platform/descriptor")
local PlatformDescriptor = descriptors.PlatformDescriptor
local ExecutableDescriptor = descriptors.ExecutableDescriptor
local ProgressBar = require("@self/utils/progress")
local compression = require("@self/compression")
local manifest = require("@self/manifest")
local sys = require("@self/utils/sys")

export type ToolId = {
	alias: Option<string>,
	repo: string,
	version: Option<string>,
}

-- TODO: Remove this in a breaking change
export type GithubReleases = Github.GithubReleases

local ERROR_PREFIX = `{stdio.color("red")}{stdio.style("bold")}error{stdio.color("reset")}:`
local _INFO_PREFIX = `{stdio.color("green")}{stdio.style("bold")}info{stdio.color("reset")}:`
local WARN_PREFIX = `{stdio.color("yellow")}{stdio.style("bold")}warn{stdio.color("reset")}:`

local function warn(...)
	stdio.ewrite(`{WARN_PREFIX} {stdio.format(...)}\n`)
end

local function downloadAndExtractBinary(
	binaryName: string,
	targetPlatform: descriptors.PlatformDescriptor,
	asset: {
		name: string,
		browser_download_url: string,
		size: number,
		content_type: string,
	}
): Option<buffer>
	return compression
			.detectFormat(asset.name)
			:andThen(function(format: compression.CompressionFormat)
				local contentsResp = net.request(asset.browser_download_url)
				if not contentsResp.ok then
					return error(`Failed to download asset {asset.name}: HTTP Code {contentsResp.statusCode}`)
				end

				local extracted = compression.extractBinary
					[format](buffer.fromstring(contentsResp.body), binaryName, targetPlatform)
					:unwrap()
				return Option.Some(extracted)
			end) :: Option<buffer>
end

local function chmod(path: pathfs.Path, mode: number | string)
	if process.os == "windows" then
		return
	end

	local result =
		process.exec("chmod", { if typeof(mode) == "string" then mode else string.format("%o", mode), path:toString() })

	if not result.ok then
		return error(result.stderr)
	end
end

local function toolAliasOrDefault(tool: ToolId): string
	return tool.alias:unwrapOr(string.split((tool :: ToolId).repo, "/")[2])
end

local function stripLeadingVersion(version: string): string
	local stripped = string.gsub(version, "^v", "")
	return stripped
end

local function stripToolchainlibRev(version: string)
	version = version:gsub("[%.|%-]?toolchainlib%.%d+", ""):gsub("%+$", "")

	return version
end

local HOME_DIR = (
	if process.env.PESDE_HOME
		then pathfs.Path.from(process.env.PESDE_HOME)
		else assert(dirs.homeDir(), "Couldn't get home dir :("):join(".pesde")
)

local LINK_INSTALL_DIR = HOME_DIR:join("bin")
local TOOL_STORAGE_DIR = LINK_INSTALL_DIR:join(".tool_storage")
if not fs.isDir(TOOL_STORAGE_DIR) then
	fs.writeDir(TOOL_STORAGE_DIR)
end

local OLD_TOOL_STORAGE_DIR = LINK_INSTALL_DIR:join("tool_storage")
if fs.isDir(OLD_TOOL_STORAGE_DIR) and not fs.isDir(TOOL_STORAGE_DIR) then
	-- TODO: Merge both directories into one instead of a single move
	fs.move(OLD_TOOL_STORAGE_DIR, TOOL_STORAGE_DIR)
end

local bar = ProgressBar.new()
	:withStage("init", "Initializing")
	:withStage("fetch", "Fetching release")
	:withStage("locate", "Identifying asset")
	:withStage("download", "Downloading")
	:withStage("install", "Installing")

function runTool(tool: ToolId | pathfs.Path, args: { string }?): number
	-- FIXME: `process.spawn` has a bug where interactive features don't
	-- forward properly
	local toolId = tool :: ToolId
	local path = if (toolId :: any).alias ~= nil
		then LINK_INSTALL_DIR:join(toolAliasOrDefault(toolId))
		else tool :: pathfs.Path

	return process.exec(path:toString(), args or process.args, {
		cwd = process.cwd,
		env = process.env,
		stdio = "forward",
	}).code
end

local function makeConditionalBar()
	local function makeConditional(fn: (ProgressBar.ProgressBarImpl) -> ())
		return function(bar: ProgressBar.ProgressBarImpl)
			if _G.interactive then
				return fn(bar)
			end

			return
		end
	end

	return {
		next = makeConditional(function(bar)
			return bar:nextStage():unwrap()
		end),
		start = makeConditional(bar.start),
		stop = makeConditional(bar.stop),
	}
end

local function getGithubToken(): Option<string>
	return Option.from(process.env.GITHUB_TOKEN):orElse(function()
		return ResultExt.ok(Result.try(process.exec, "gh", { "auth", "token" }))
			:andThen(function(child: process.ExecResult)
				if not child.ok then
					return Option.None
				end

				-- Remove newlines and other control characters
				local token = string.gsub(child.stdout, "%s+", "")
				return Option.Some(token)
			end)
	end)
end

local function isInteractive(): boolean
	return process.env.PESDE_TOOLING_FORCE_INTERACTIVE ~= nil
		or (sys.isTTY("stdout") and process.env.TERM ~= "dumb" and process.env.CI == nil)
end

-- Initialize the shared global progress bar state
_G.interactive = isInteractive() or nil
local barFns

function installTool(tool: ToolId, installPath: pathfs.Path): nil
	-- Configure the conditional progress bar
	barFns = makeConditionalBar()
	barFns.start(bar) -- init

	-- If the tool installation directory was not present, we create it
	local toolDir = assert(installPath:parent(), "Install path did not have parent dir")
	if not fs.isDir(toolDir) then
		fs.writeDir(toolDir)
	end

	type InstallLock = {
		expiration: number,
		resource: string,
	}

	local installLockFile = toolDir:join("LOCK")

	--- Attempts to write a lock file to prevent concurrent installation attempts, returning
	--- true if a lock is already held, along with optionally its contents. A lock may be
	--- denoted as being held but may have no contents returned in some rare cases where
	--- the lock file may have been released before the contents have been read.
	local function tryAcquireLock(): (boolean, string?)
		local lockFile: InstallLock = {
			resource = installPath:toString(),
			expiration = os.time() + 60, -- lock expires in 60s from time of issue
		}

		-- NOTE: We first write to a temporary file and then move it, since moves are
		-- atomic on unix and windows, preventing a TOCTOU race condition

		local lockFileContents = serde.encode("json", lockFile)
		local tmpLockFile = dirs.createTempFile(toolDir, "LOCK", "tmp")
		fs.writeFile(tmpLockFile.path, lockFileContents)

		local ok, contents = pcall(fs.move, tmpLockFile.path, installLockFile)
		if not ok then
			local _
			_, contents = pcall(fs.readFile, installLockFile)
		end

		return not ok, contents
	end

	-- Attempt to acquire an on-disk lock
	local isLocked, lockFileContents = tryAcquireLock()
	if isLocked then
		-- Disable the progress bar since we're not actually an installation process
		barFns.stop(bar)
		_G.interactive = false

		-- Display warning about wait
		warn("Waiting for existing installation process for tool to exit")
	end

	while isLocked do
		-- If an installation lock was held for the tool we are trying to install, it means
		-- that it is also being installed elsewhere. In this case, we wait for that installation
		-- attempt to finish, i.e., when the lock file is removed, and then run the freshly
		-- installed tool

		local lockFile: InstallLock? = lockFileContents and serde.decode("json", lockFileContents)
		if lockFile ~= nil then
			assert(lockFile.resource == installPath:toString(), "Mismatch between lock and expected resource")
		end

		if lockFile ~= nil and os.time() > lockFile.expiration then
			-- If more than 60s has passed since we started waiting for the lock
			-- to be released, we assume something went wrong and error; this should
			-- also remove the lock for subsequent runs
			error("Installation lock was held for too long (>60s)")
		end

		task.wait(1)
		isLocked, lockFileContents = pcall(fs.readFile, installLockFile)
		if not isLocked then
			return nil
		end
	end

	local toolAlias = toolAliasOrDefault(tool)
	local client = Github.new(
		tool.repo,
		Option.Some({
			authToken = getGithubToken(),
			retries = Option.None :: Option<number>,
		}) :: Option<Github.Config>
	)

	barFns.next(bar) -- fetch
	local releases = client:queueTransactions({ "FetchReleases" })[1]:unwrap() :: GithubReleases
	local assets = tool.version:match({
		Some = function(version: string)
			for _, release in releases do
				if stripLeadingVersion(release.tag_name) == stripLeadingVersion(version) then
					return release.assets
				end
			end

			return error(`No release found for version {version}`)
		end,

		None = function()
			return releases[0].assets
		end,
	})

	barFns.next(bar) -- locate

	-- TODO: Use index type fn in solver v2
	local matchingAsset: {
		name: string,
		browser_download_url: string,
		size: number,
		content_type: string,
	}

	local currentDesc = PlatformDescriptor.currentSystem()
	local aliasPath = pathfs.Path.from(toolAlias):withExtension(if currentDesc.os == "windows" then "exe" else "")
	local aliasName = aliasPath:toString()

	for _, asset in assets do
		local desc = ExecutableDescriptor.fromString(asset.name)

		if desc:isOk() and PlatformDescriptor.matches(currentDesc, desc:unwrap()) then
			matchingAsset = asset
			break
		end
	end

	barFns.next(bar) -- download

	local binaryContents: buffer?
	if matchingAsset == nil then
		if _G.interactive then
			-- Clear the current progress bar line
			stdio.ewrite("\x1b[2K\x1b[0G")
		end

		-- Output warnings
		warn("pesde could not find a matching binary for your system")
		warn("Will now attempt to download all binaries and find a matching one")

		for _, asset in assets do
			local contents = downloadAndExtractBinary(aliasName, currentDesc, asset)
			if contents:isSome() then
				binaryContents = contents:unwrap()
				break
			end
		end
	else
		binaryContents = downloadAndExtractBinary(aliasName, currentDesc, matchingAsset):unwrapOrNil()
	end

	assert(binaryContents, `No matching binary found`)

	barFns.next(bar) -- install

	fs.writeFile(installPath, binaryContents)

	-- IDEA: In order to eliminate fs read overhead on startup and to disallow
	-- the use of the tool binary when outside a package where it is installed,
	-- we can improve this by following what rokit does, where we symlink
	-- the tool's path to this script, and check the file that we are being
	-- invoked as, in order to figure out what tool to execute

	-- We can create "linker" scripts for each tool at ~/.pesde/bins with
	-- contents like so:
	--[[
		#!/bin/env -S lune run

		-- First off, we check whether the tool is installed in pesde.toml
		-- if we're being run as a symlink, and not a `pesde x` bin

		local pathInfo = debug.info(1, "s")
		local path = string.sub(pathInfo, 10, #pathInfo - 2))

		-- Now we can use `path` to figure out the real tool to execute
		-- ...
	]]

	barFns.stop(bar)

	-- NOTE: This is equivalent to `0o755` or `rwxr-xr-x`
	chmod(installPath, 0b10101010011)

	-- Release the installation lock
	fs.removeFile(installLockFile)

	return nil
end

type LibExports = {
	runTool: (pathfs.Path | ToolId, args: { string }?) -> number,
	installTool: (ToolId, pathfs.Path) -> nil,
}
type LibExportsImpl = typeof(setmetatable(
	{} :: LibExports,
	{ __call = function(lib: LibExportsImpl, tool: string, pesdeRoot: string?, args: { string }?) end }
))

return setmetatable(
	{
		runTool = runTool,
		installTool = installTool,
	} :: LibExports,
	{
		__call = function(lib: LibExportsImpl, tool: string, pesdeRoot: string?, args: { string }?): number
			local repo, version = string.match(tool, "([^@]+)@?(.*)")
			if repo == nil or version == nil then
				stdio.ewrite(`{ERROR_PREFIX} Invalid tool provided\n`)
				return 1
			end

			local function manifestVersion(): (number, string?)
				if pesdeRoot == nil then
					stdio.ewrite(`{ERROR_PREFIX} Failed to discover pesde package root\n`)
					return 1, nil
				end

				-- Use _G.PESDE_ROOT to get the install directory, then decode the
				-- pesde manifest to get the version of the tool dynamically
				local manifestContents = fs.readFile(pathfs.Path.from(pesdeRoot :: string):join("pesde.toml"))
				local ok, manifest: manifest.PesdeManifest = pcall(serde.decode, "toml" :: "toml", manifestContents)
				if not ok then
					stdio.ewrite(
						`{ERROR_PREFIX} Failed to decode bundled manifest. This is probably a bug.\n\n{manifest}`
					)
					return 1, nil
				end

				return 0, manifest.version
			end

			local versionOrDefault: string = version :: string
			if versionOrDefault == "" then
				local code, ver = manifestVersion()
				if code ~= 0 then
					return code
				end
				versionOrDefault = ver :: string
			end

			-- Strip out any optional toolchainlib revision from the build metadata part
			versionOrDefault = stripToolchainlibRev(versionOrDefault)

			local toolId = string.gsub(repo :: string, "/", "+")
			local toolAlias = string.split(toolId, "+")[2]
			local toolInstallPath = TOOL_STORAGE_DIR:join(toolId):join(versionOrDefault):join(toolAlias)

			if not fs.isFile(toolInstallPath) then
				local ok, err = pcall(
					lib.installTool,
					{
						alias = Option.None,
						repo = repo,
						version = Option.Some(versionOrDefault),
					} :: ToolId,
					toolInstallPath
				)

				if not ok then
					-- Cleanup any failure remnants from installation directory
					fs.removeDir(toolInstallPath:parent() :: pathfs.Path)

					-- Cleanup progress bar in case of error
					barFns.stop(bar)

					stdio.ewrite(`{ERROR_PREFIX} Failed to install {tool}\n`)
					stdio.ewrite(`	- {err}\n`)
					return 1
				end
			end

			return lib.runTool(toolInstallPath, args)
		end,
	}
)
