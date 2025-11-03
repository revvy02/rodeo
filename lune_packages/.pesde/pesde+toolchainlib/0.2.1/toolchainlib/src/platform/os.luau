--> Mostly a recreation of rokit's detection logic in Luau
--> See https://github.com/rojo-rbx/rokit/blob/a6b84c/lib/descriptor/os.rs

local process = require("@lune/process")

local detection = require("./detection")

local Option = require("../../lune_packages/option")
type Option<T> = Option.Option<T>

local OS_SUBSTRINGS: { [process.OS]: { string } } = {
	windows = { "windows" },
	macos = { "macos", "darwin", "apple" },
	linux = { "linux", "ubuntu", "debian", "fedora" },
}

local OS_FULL_WORDS: { [process.OS]: { string } } = {
	windows = { "win", "win32", "win64" },
	macos = { "mac", "osx" },
	linux = {},
}

return {
	detect = function(str: string): Option<process.OS>
		return detection.detect(str, OS_SUBSTRINGS, OS_FULL_WORDS)
	end,

	detectFromExecutable = function(binaryContents: buffer): Option<process.OS>
		return Option.from(detection.detectFromExecutable(binaryContents))
			:map(function(inner: detection.ExecutableDescriptor)
				return inner.os
			end)
	end,
}
