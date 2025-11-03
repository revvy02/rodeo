local executable = require("@self/executable")
export type ExecutableDescriptor = executable.ExecutableDescriptor

return {
	detect = require("@self/pattern"),
	detectFromExecutable = executable,
}
