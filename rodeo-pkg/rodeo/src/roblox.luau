-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Camera and device options for `capture`. All fields optional.
--- `cframe` — scripted camera position for the shot (restored after).
--- `fov` — field of view. `focus` — camera focus CFrame (defaults to 100 studs
--- along `cframe`'s look vector when `cframe` is set). `settle` — seconds to
--- wait before capturing.
--- `device` — a Studio device-simulator preset id to capture as (for example
--- `"iphone_13"` or `"hd_1080"`); layout, insets and orientation come from the
--- preset. `viewportSize` — the `Camera.ViewportSize` to capture at, as a
--- custom desktop device (width at most 7680); with `device`, overrides the
--- preset's resolution. Either drives Studio's device simulator for the shot
--- and restores it afterward, the way the camera fields are restored.
export type CaptureOptions = {
	cframe: CFrame?,
	fov: number?,
	focus: CFrame?,
	settle: number?,
	device: string?,
	viewportSize: Vector2?,
}

--- Size of the written image in pixels. Always the capture's
--- `Camera.ViewportSize`: the engine's frame is larger on high-DPI displays and
--- is resampled down to it, so a capture is the same size on every machine and
--- offset-based UI maps 1:1 onto pixels.
export type CaptureInfo = {
	width: number,
	height: number,
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

--- Captures a Studio screenshot and writes it to a stable path, returning
--- that absolute path and the image size. `output` ending in `.png` is the
--- exact file path; any other value is a directory the auto-named `.png` lands
--- in; omitted defaults to the `.rodeo/.temp/captures` directory. Relative
--- paths resolve against the run client's cwd. The image is always exactly
--- the capture's `Camera.ViewportSize` (the window's, or `viewportSize` /
--- the `device` preset's). Camera and device-simulator state are restored
--- after the capture, on error too. Requires a viewport (plugin context, or
--- client context in a running session). macOS and Windows only; other
--- platforms error. Frames beyond roughly 16384 physical pixels never
--- complete and fail after 10s, as does a minimized Studio on Windows
--- (background launches are minimized there; launch focused or restore the
--- window).
function roblox.capture(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	return (singleton :: any).roblox.capture(output, options)
end

return roblox
