-- Run from the repository root: rodeo run --place capture.luau -- output.png
local roblox = require("@rodeo/roblox")
local process = require("@rodeo/process")
local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")

local mesh = roblox.importEditableMesh("tests/fixtures/pkg/obj/concave.obj")
local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
    CollisionFidelity = Enum.CollisionFidelity.Box,
})
part.Anchored = true
part.DoubleSided = true
part.Material = Enum.Material.SmoothPlastic
part.Color = Color3.fromRGB(24, 172, 194)
part.CFrame = CFrame.new(0, 1000, 0)
part.Parent = workspace

local backdrop = Instance.new("Part")
backdrop.Anchored = true
backdrop.Size = Vector3.new(20, 20, 0.1)
backdrop.CFrame = CFrame.new(0, 1000, -0.2)
backdrop.Material = Enum.Material.Neon
backdrop.Color = Color3.fromRGB(24, 28, 36)
backdrop.Parent = workspace
Lighting.GlobalShadows = false
Lighting.Brightness = 0
Lighting.Ambient = Color3.new(1, 1, 1)
Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
for _, effect in Lighting:GetChildren() do
    if effect:IsA("PostEffect") then effect:Destroy() end
end
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(1.5, 1001.5, 8), Vector3.new(1.5, 1001.5, 0))
camera.Focus = CFrame.new(1.5, 1001.5, 0)
camera.FieldOfView = 35
local area, reversed = 0, 0
for _, face in mesh:GetFaces() do
    local vertices = mesh:GetFaceVertices(face)
    local a, b, c = mesh:GetPosition(vertices[1]), mesh:GetPosition(vertices[2]), mesh:GetPosition(vertices[3])
    local cross = (b - a):Cross(c - a)
    area += cross.Magnitude / 2
    if cross.Z < 0 then reversed += 1 end
end
local path = roblox.captureViewport(process.args[1], { viewportSize = Vector2.new(960, 720), settle = 2 })
part:Destroy()
backdrop:Destroy()
mesh:Destroy()
return { path = path, area = area, reversed = reversed }
