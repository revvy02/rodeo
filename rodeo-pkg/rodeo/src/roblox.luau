-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Camera options for `capture`. All fields optional.
--- `cframe` — scripted camera position for the shot (restored after).
--- `fov` — field of view. `focus` — camera focus CFrame (defaults to 100 studs
--- along `cframe`'s look vector when `cframe` is set). `settle` — seconds to
--- wait before capturing.
export type CaptureOptions = {
	cframe: CFrame?,
	fov: number?,
	focus: CFrame?,
	settle: number?,
}

--- Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances.
function roblox.import(path: string): { Instance }
	return (singleton :: any).roblox.import(path)
end

--- Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`.
function roblox.export(path: string, instances: { Instance })
	(singleton :: any).roblox.export(path, instances)
end

--- Captures a Studio screenshot and copies it to a stable path, returning
--- that absolute path. `output` ending in `.png` is the exact file path; any
--- other value is a directory the auto-named `.png` lands in; omitted
--- defaults to the `.rodeo-screenshots` directory. Relative paths resolve
--- against the run client's cwd. Temporary scripted-camera state is restored
--- after the capture. Requires a viewport (plugin context, or client context
--- in a running session). macOS only.
function roblox.capture(output: string?, options: CaptureOptions?): string
	return (singleton :: any).roblox.capture(output, options)
end

return roblox
