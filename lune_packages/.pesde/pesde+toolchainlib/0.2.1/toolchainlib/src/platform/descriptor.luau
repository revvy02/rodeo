local process = require("@lune/process")

local os = require("./os")
local arch = require("./arch")
local toolchain = require("./toolchain")
local result = require("./result")
local detectFromExecutable = require("./detection/executable")

local Result = require("../../lune_packages/result")
local Option = require("../../lune_packages/option")
local OptionExt = require("../utils/ext/option")
type Result<T, E> = Result.Result<T, E>
type Option<T> = Option.Option<T>

local PlatformDescriptor = {}
export type PlatformDescriptor = {
	os: process.OS,
	arch: Option<arch.Arch>,
	toolchain: Option<toolchain.Toolchain>,
}
local ExecutableDescriptor = {}
type ExecutableDescriptor = detectFromExecutable.ExecutableDescriptor

function PlatformDescriptor.currentSystem(): PlatformDescriptor
	return {
		os = process.os,
		arch = Option.Some(process.arch) :: Option<arch.Arch>,
		toolchain = Option.None :: Option<toolchain.Toolchain>,
	}
end

function ExecutableDescriptor.fromString(str: string): result.PlatformResult<ExecutableDescriptor>
	local detectedOs = os.detect(str)
	if detectedOs:isNone() then
		return Result.Err("NoPatternDetected" :: result.PlatformError) :: result.PlatformResult<ExecutableDescriptor>
	end

	return Result.Ok({
		os = detectedOs:unwrap() :: process.OS,
		arch = arch.detect(str):mapOr({}, function(arch)
			return { arch }
		end),
	}) :: result.PlatformResult<ExecutableDescriptor>
end

function ExecutableDescriptor.fromExecutable(contents: buffer): result.PlatformResult<ExecutableDescriptor>
	local detected = Option.from(detectFromExecutable(contents))

	return OptionExt.okOr(
			detected,
			"NoExecutableDetected" :: result.PlatformError
		) :: result.PlatformResult<ExecutableDescriptor>
end

function PlatformDescriptor.matches(self: PlatformDescriptor, executable: ExecutableDescriptor): boolean
	if self.os ~= executable.os then
		return false
	end

	if self.arch:isNone() or table.find(executable.arch, self.arch:unwrap()) then
		return true
	end

	return false
end

return {
	PlatformDescriptor = PlatformDescriptor,
	ExecutableDescriptor = ExecutableDescriptor,
}
