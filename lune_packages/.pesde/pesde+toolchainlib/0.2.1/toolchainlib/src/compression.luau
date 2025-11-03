local process = require("@lune/process")

local dirs = require("../lune_packages/dirs")
local pathfs = require("../lune_packages/pathfs")
local unzip = require("../luau_packages/unzip")

local Result = require("../lune_packages/result")
local Option = require("../lune_packages/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local revTable = require("./utils/rev_table")
local descriptors = require("./platform/descriptor")
local PlatformDescriptor = descriptors.PlatformDescriptor
local ExecutableDescriptor = descriptors.ExecutableDescriptor

export type CompressionFormat = "TarGz" | "TarXz" | "Zip"

local function detectFormat(fileName: string): Option<CompressionFormat>
	local fileNameParts = string.split(string.lower(fileName), ".")
	revTable(fileNameParts)

	if fileNameParts[1] == "zip" then
		return Option.Some("Zip" :: CompressionFormat)
	end

	if fileNameParts[2] == "tar" then
		if fileNameParts[1] == "gz" then
			return Option.Some("TarGz" :: CompressionFormat)
		end

		if fileNameParts[1] == "xz" then
			return Option.Some("TarXz" :: CompressionFormat)
		end
	end

	return Option.None :: Option<CompressionFormat>
end

-- TODO: Use a type function to make all CompressionFormat lowercase
local extractBinary: {
	[CompressionFormat]: (
		compressed: buffer,
		binaryName: string,
		targetPlatform: descriptors.PlatformDescriptor
	) -> Result<buffer, string>,
} =
	{
		Zip = function(compressed, binaryName, targetPlatform)
			-- Load the compressed data into a `ZipReader`
			local reader = unzip.load(compressed)
			local binaryContents: buffer?

			--- Extracts a specific entry from the ZIP and validates that its `PlatformDescriptor`
			--- matches the expected one
			local function extractEntry(entry: unzip.ZipEntry): buffer?
				local contents = reader:extract(entry, { type = "binary" }) :: buffer
				local executablePlatform = ExecutableDescriptor.fromExecutable(contents)

				if
					executablePlatform:isOkAnd(function(platform)
						return PlatformDescriptor.matches(targetPlatform, platform)
					end)
				then
					return contents
				end

				return nil
			end

			-- Find the entry and attempt to extract it
			local binaryEntry = reader:findEntry(binaryName)
			if binaryEntry then
				binaryContents = extractEntry(binaryEntry)
			end

			-- Fallback for if we cannot find the `ZipEntry`
			if binaryContents == nil then
				-- Walk through the entries to find an executable
				reader:walk(function(entry)
					if binaryContents ~= nil then
						-- If we successfully extracted the binary on a previous iteration,
						-- we skip this entry
						return
					end

					if entry.isDirectory then
						-- Ignore directories
						return
					end

					binaryContents = extractEntry(entry)
				end)
			end

			if binaryContents == nil then
				-- If both the fallback and the initial attempts did not yield an extracted binary,
				-- we return an error
				return Result.Err("ExtractBinaryError::BinaryNotFound" :: string)
			end

			return Result.Ok(binaryContents)
		end,

		TarXz = function(compressed, binaryName, targetPlatform)
			local extractionDir = dirs.createTempDir(nil, "pesde-tooling")
			local tarResult = process.exec(
				"tar",
				{ "-xJf", "-", "-C", extractionDir.path:toString(), "--strip-components=1" },
				{
					stdio = {
						stdin = compressed,
					},
				}
			)

			if not tarResult.ok then
				return Result.Err(
					`ExtractBinaryError::Decompression(msg={tarResult.stderr},code={tarResult.code})` :: string
				)
			end

			local ok, binaryContentsStr =
				pcall(pathfs.fs.readFile, pathfs.Path.from(tostring(extractionDir)):join(binaryName))
			if ok then
				return Result.Ok(buffer.fromstring(binaryContentsStr))
			end

			for _, entry in extractionDir:readDir() do
				local entryPath = extractionDir.path:join(entry)
				if not pathfs.fs.isFile(entryPath) then
					continue
				end

				local contents = buffer.fromstring(pathfs.fs.readFile(entryPath))
				local executablePlatform = ExecutableDescriptor.fromExecutable(contents)

				if
					executablePlatform:isOkAnd(function(platform)
						return PlatformDescriptor.matches(targetPlatform, platform)
					end)
				then
					return Result.Ok(contents)
				end
			end

			return Result.Err("ExtractBinaryError::BinaryNotFound" :: string)
		end,
	}

return { extractBinary = extractBinary, detectFormat = detectFormat }
