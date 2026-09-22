-- @rodeo run --place ./.rodeo/map/town.rbxl
--
-- Map render demo: open the town that buildMap.luau saved and capture it from
-- straight above at the largest size the engine will render. Run buildMap.luau
-- first; both from the repo root, since the directive paths are relative to
-- the cwd.
--
-- The device simulator caps the viewport at 7680x4320. In ScaleToPhysicalSize
-- mode it renders that viewport at host DPI / pixel density, and density
-- floors at 72, so on a 220 DPI display (2x Retina) the frame is 3.06x:
-- 23466x13200, about 310 megapixels. `resample = false` keeps that frame
-- instead of shrinking it back to the viewport. On a 1x monitor the same
-- script gives about 11700x6600; the image is whatever your display allows.
--
-- Roblox has no orthographic camera, so this is a narrow-FOV perspective shot
-- from high up: at FOV 10 the visible span is about 0.175 x height, so 2930
-- studs sees about 513 studs across, the town's 512. Straight down, north (-Z)
-- at the top. Expect roughly 10-20 seconds and over a gigabyte of host memory
-- while the frame is processed.

local roblox = require("@rodeo/roblox")
local sim = game:GetService("StudioDeviceSimulatorService")

-- Drive the simulator ourselves for the physical-size mode captureViewport's
-- own viewportSize option does not use, and put it back afterwards.
local device = "renderMap"
pcall(function() sim:RemoveDeviceAsync(device) end)
sim:SetDeviceAsync(sim:CreateDeviceAsync({ Name = device, Width = 7680, Height = 4320, PixelDensity = 96, DeviceForm = Enum.DeviceForm.Desktop }))
sim:SetScalingModeAsync(Enum.DeviceSimulatorScalingMode.ScaleToPhysicalSize)
sim:SetPixelDensityAsync(72)

local ok, path, info = pcall(roblox.captureViewport, ".rodeo/map/map.png", {
	cframe = CFrame.lookAt(Vector3.new(0, 2930, 0), Vector3.zero, Vector3.new(0, 0, -1)),
	fov = 10,
	focus = CFrame.new(0, 0, 0),
	resample = false,
	settle = 3,
})

pcall(function() sim:StopSimulationAsync() end)
pcall(function() sim:RemoveDeviceAsync(device) end)
if not ok then
	error(path, 0)
end
print(`map: {info.width}x{info.height} -> {path}`)
return path
