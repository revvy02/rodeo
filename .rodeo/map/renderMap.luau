-- @rodeo run --place ./.rodeo/map/town.rbxl
--
-- Map render demo: open the town that buildMap.luau saved and capture it from
-- straight above as a square top-down map. Run buildMap.luau first; both from
-- the repo root, since the directive paths are relative to the cwd.
--
-- Roblox has no orthographic camera, so this is a narrow-FOV perspective shot
-- from high up: at FOV 10 the visible span is about 0.175 x height, so 2930
-- studs sees about 513 studs across, the town's 512. The camera looks straight
-- down with north (-Z) at the top of the image, and a square viewport keeps
-- the map square. To map your own place, change the directive's path and the
-- values in the call.

local roblox = require("@rodeo/roblox")

local path, info = roblox.captureViewport(".rodeo/map/map.png", {
	cframe = CFrame.lookAt(Vector3.new(0, 2930, 0), Vector3.zero, Vector3.new(0, 0, -1)),
	fov = 10,
	focus = CFrame.new(0, 0, 0),
	viewportSize = Vector2.new(4096, 4096),
	settle = 3,
})
print(`map: {info.width}x{info.height} -> {path}`)
return path
