--> Mostly a recreation of rokit's detection logic in Luau
--> See https://github.com/rojo-rbx/rokit/blob/a6b84c/lib/descriptor/arch.rs

local process = require("@lune/process")
local detection = require("./detection")

local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>

export type Arch = process.Arch | "arm" | "x86"

local ARCH_SUBSTRINGS: { [Arch]: { string } } = {
	aarch64 = { "aarch64", "arm64", "armv9" },
	x86_64 = { "x86-64", "x86_64", "amd64", "win64", "win-x64" },
	arm = { "arm32", "armv7" },
	x86 = { "i686", "i386", "win32", "win-x86" },
}

local ARCH_FULL_WORDS: { [Arch]: { string } } = {
	aarch64 = {},
	x86_64 = { "x64", "win" },
	arm = { "arm" },
	x86 = { "x86" },
}

return {
	detect = function(str: string): Option<Arch>
		return detection.detect(str, ARCH_SUBSTRINGS, ARCH_FULL_WORDS)
	end,

	detectFromExecutable = function(binaryContents: buffer)
		return Option.from(detection.detectFromExecutable(binaryContents))
			:map(function(inner: detection.ExecutableDescriptor)
				return inner.arch
			end)
	end,
}
