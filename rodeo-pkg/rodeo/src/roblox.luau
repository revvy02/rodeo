-- Roblox-flavored helpers.
-- Bundled require: `local roblox = require("@rodeo/roblox")`.

local singleton = require("./_internal/singleton")

local roblox = {}

--- Camera and device options for `captureViewport`. All fields optional.
--- `cframe` — scripted camera position for the shot (restored after).
--- `fov` — field of view. `focus` — camera focus CFrame (defaults to 100 studs
--- along `cframe`'s look vector when `cframe` is set). `settle` — seconds to
--- wait before capturing.
--- `device` — a Studio device-simulator preset id to capture as (for example
--- `"iphone_13"` or `"hd_1080"`); layout, insets and orientation come from the
--- preset. `viewportSize` — the `Camera.ViewportSize` to capture at, as a
--- custom desktop device (at most 7680 by 4320); with `device`, overrides the
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

--- Size of the image `captureViewport` wrote, in pixels. Always the capture's
--- `Camera.ViewportSize`: the engine's frame is larger on high-DPI displays and
--- is resampled down to it, so a capture is the same size on every machine and
--- offset-based UI maps 1:1 onto pixels.
export type CaptureInfo = {
	width: number,
	height: number,
}

--- Imports a `.rbxm` or `.rbxmx` model file at `path` as Instances.
function roblox.importInstances(path: string): { Instance }
	return (singleton :: any).roblox.importInstances(path)
end

--- Deprecated alias of `roblox.importInstances`.
--- :::caution[Deprecated]
--- Use `roblox.importInstances`. This alias warns once per run and will be
--- removed in 2.0.
--- :::
function roblox.import(path: string): { Instance }
	return (singleton :: any).roblox.import(path)
end

--- Exports `instances` as a `.rbxm` or `.rbxmx` model file at `path`.
function roblox.exportInstances(path: string, instances: { Instance })
	(singleton :: any).roblox.exportInstances(path, instances)
end

--- Deprecated alias of `roblox.exportInstances`.
--- :::caution[Deprecated]
--- Use `roblox.exportInstances`. This alias warns once per run and will be
--- removed in 2.0.
--- :::
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

--- Writes an `EditableImage`'s pixels to `path` as a PNG. Only `.png` is
--- supported. Parent directories are created as needed. EditableImage has no
--- file representation of its own (`export` writes an Object-backed image
--- content as an empty reference), so this is how generated textures reach
--- the source tree.
function roblox.exportEditableImage(path: string, image: EditableImage)
	(singleton :: any).roblox.exportEditableImage(path, image)
end

--- Loads the PNG or JPEG at `path` into a new `EditableImage` (RGBA8) and
--- returns it. Relative paths resolve against the run client's cwd. Studio
--- bounds EditableImage dimensions; an image it refuses errors with its size.
function roblox.importEditableImage(path: string): EditableImage
	return (singleton :: any).roblox.importEditableImage(path)
end

--- Writes an `EditableMesh` to `path` as glTF 2.0: `.glb` (binary) or
--- `.gltf` (JSON with an embedded buffer). Positions, faces, per-corner
--- normals, UVs and colors, and skinning (bones with bind poses, up to four
--- influences per vertex) are written; FACS poses are not. Faces must be
--- triangles (`mesh:Triangulate()` first). glTF's conventions are Roblox's, so
--- nothing is converted: studs, Y-up, right-handed, UV origin top-left.
function roblox.exportEditableMesh(path: string, mesh: EditableMesh)
	(singleton :: any).roblox.exportEditableMesh(path, mesh)
end

--- Loads the `.glb` or `.gltf` at `path` into a new `EditableMesh` and returns
--- it. Node transforms are baked into the geometry, all primitives merge into
--- one mesh, and a skin becomes bones plus vertex weights. An attribute
--- (normals, UVs, colors) is kept only when every primitive carries it.
--- Relative paths resolve against the run client's cwd. Turn the result into a
--- part with `AssetService:CreateMeshPartAsync(Content.fromObject(mesh), opts)`.
function roblox.importEditableMesh(path: string): EditableMesh
	return (singleton :: any).roblox.importEditableMesh(path)
end

--- Captures a Studio screenshot and writes it to a stable path, returning
--- that absolute path and the image size. `output` ending in `.png` is the
--- exact file path; any other value is a directory the auto-named `.png` lands
--- in; omitted defaults to the `.rodeo/.temp/captures` directory. Relative
--- paths resolve against the run client's cwd. The image is always exactly
--- the capture's `Camera.ViewportSize` (the window's, or `viewportSize` /
--- the `device` preset's). Camera and device-simulator state are restored
--- after the capture, on error too. Requires a viewport: plugin context, or
--- the client DOM of a running session. The frame is taken from the file the
--- engine writes for every capture, so the simulator's full 7680 by 4320
--- works on every display; a frame the engine did not render is refused
--- rather than written: a solo play-test session (`--mode test`) captures
--- black on macOS, so capture from a multiplayer session (`--mode play`) or
--- in edit mode. Limits are Studio's own and surface as errors: the device
--- simulator accepts at most 7680 by 4320. The capture then waits for the
--- engine with no deadline, since a large frame or a slow GPU can take well
--- over 10s (the largest frame takes about 7s). One case never completes and
--- waits until the run is killed: a minimized Studio on Windows (background
--- launches are minimized there; launch focused or restore the window).
function roblox.captureViewport(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	return (singleton :: any).roblox.captureViewport(output, options)
end

--- Deprecated alias of `roblox.captureViewport`.
--- :::caution[Deprecated]
--- Use `roblox.captureViewport`. This alias warns once per run and will be
--- removed in 2.0.
--- :::
function roblox.capture(output: string?, options: CaptureOptions?): (string, CaptureInfo)
	return (singleton :: any).roblox.capture(output, options)
end

return roblox
