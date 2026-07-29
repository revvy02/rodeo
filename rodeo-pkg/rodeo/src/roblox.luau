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

--- Writes `value` to `path` as a Luau module (`return <value>`), so the data
--- can be required straight back into Studio. Roblox types round-trip through
--- their constructors (vectors, CFrames, colors, enums, …); values with no
--- source representation (Instances, functions) become their `tostring`.
--- Parent directories are created as needed. This is the same path
--- `--return <file>.luau` uses.
function roblox.bake(path: string, value: any)
	(singleton :: any).roblox.bake(path, value)
end

--- Captures a Studio screenshot and copies it to a stable path, returning
--- that absolute path. `output` ending in `.png` is the exact file path; any
--- other value is a directory the auto-named `.png` lands in; omitted
--- defaults to the `.rodeo-screenshots` directory. Relative paths resolve
--- against the run client's cwd. Temporary scripted-camera state is restored
--- after the capture. Requires a viewport (plugin context, or client context
--- in a running session). macOS and Windows only; other platforms error. On
--- Windows a minimized Studio never renders its viewport, and background
--- launches are minimized, so a capture there must be launched focused (or
--- the window restored) or it fails after 10s.
function roblox.capture(output: string?, options: CaptureOptions?): string
	return (singleton :: any).roblox.capture(output, options)
end

return roblox
