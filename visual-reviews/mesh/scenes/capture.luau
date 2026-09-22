-- @rodeo run --place --port 46120
local roblox = require("@rodeo/roblox")
local assets = game:GetService("AssetService")
local lighting = game:GetService("Lighting")
lighting.ClockTime = 13
lighting.Brightness = 2
lighting.Ambient = Color3.fromRGB(150, 150, 150)
local model = Instance.new("Model")
model.Name = "EditableSceneReview"
local mesh = assert(assets:CreateEditableMesh())
local positions = { Vector3.new(1.5, 1, 0), Vector3.new(4.5, 1, 0), Vector3.new(4.5, 3, 0), Vector3.new(1.5, 3, 0) }
local uv = { Vector2.new(0, 1), Vector2.new(1, 1), Vector2.new(1, 0), Vector2.new(0, 0) }
local ids, uvs = {}, {}
for i, p in positions do
	ids[i] = mesh:AddVertex(p)
	uvs[i] = mesh:AddUV(uv[i])
end
local normal = mesh:AddNormal(Vector3.zAxis)
for _, f in { { 1, 2, 3 }, { 1, 3, 4 } } do
	local id = mesh:AddTriangle(ids[f[1]], ids[f[2]], ids[f[3]])
	mesh:SetFaceUVs(id, { uvs[f[1]], uvs[f[2]], uvs[f[3]] })
	mesh:SetFaceNormals(id, { normal, normal, normal })
end
local image = assert(assets:CreateEditableImage({ Size = Vector2.new(64, 64) }))
local pixels = buffer.create(64 * 64 * 4)
local palette = { { 238, 85, 80 }, { 61, 190, 146 }, { 75, 139, 232 }, { 244, 199, 70 } }
for y = 0, 63 do
	for x = 0, 63 do
		local c = palette[1 + (x // 32) + 2 * (y // 32)]
		local i = (y * 64 + x) * 4
		buffer.writeu8(pixels, i, c[1])
		buffer.writeu8(pixels, i + 1, c[2])
		buffer.writeu8(pixels, i + 2, c[3])
		buffer.writeu8(pixels, i + 3, 255)
	end
end
image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)
local roughness = assert(assets:CreateEditableImage({ Size = Vector2.one }))
roughness:WritePixelsBuffer(Vector2.zero, Vector2.one, buffer.fromstring(string.char(255, 255, 255, 255)))
local metalness = assert(assets:CreateEditableImage({ Size = Vector2.one }))
metalness:WritePixelsBuffer(Vector2.zero, Vector2.one, buffer.fromstring(string.char(0, 0, 0, 255)))
for i = 1, 3 do
	local part =
		assets:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
	part.Name = `Panel{i}`
	part.Anchored = true
	part.DoubleSided = true
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new((i - 2) * 4, 1.7, 0) * CFrame.Angles(0, (i - 2) * 0.35, 0)
	part.Size *= Vector3.new(1, if i == 2 then 1.5 else 1, 1)
	local appearance = Instance.new("SurfaceAppearance")
	appearance.ColorMapContent = Content.fromObject(image)
	appearance.RoughnessMapContent = Content.fromObject(roughness)
	appearance.MetalnessMapContent = Content.fromObject(metalness)
	appearance.Color = Color3.new(0.8, 0.9, 1)
	appearance.AlphaMode = Enum.AlphaMode.Transparency
	appearance.Parent = part
	part.Parent = model
end
local base = Instance.new("Part")
base.Name = "Plinth"
base.Anchored = true
base.Size = Vector3.new(15, 0.5, 5)
base.CFrame = CFrame.new(0, -0.3, 0)
base.Color = Color3.fromRGB(48, 56, 72)
base.Material = Enum.Material.SmoothPlastic
base.Parent = model
model.Parent = workspace
local options =
	{ viewportSize = Vector2.new(1200, 700), fov = 45, cframe = CFrame.lookAt(
		Vector3.new(8, 6, 20),
		Vector3.new(0, 1, 0)
	), settle = 0.6 }
roblox.captureViewport("visual-reviews/mesh/scenes/baseline.png", options)
local warnings = roblox.exportEditableScene(".rodeo/.temp/scene-review.glb", { model })
model.Parent = nil
local scene = roblox.importEditableScene(".rodeo/.temp/scene-review.glb")
for _, root in scene.roots do
	root.Parent = workspace
end
roblox.captureViewport("visual-reviews/mesh/scenes/current.png", options)
for _, root in scene.roots do
	root:Destroy()
end
for _, m in scene.meshes do
	m:Destroy()
end
for _, i in scene.images do
	i:Destroy()
end
model:Destroy()
mesh:Destroy()
image:Destroy()
roughness:Destroy()
metalness:Destroy()
return { warnings = warnings, importWarnings = scene.warnings, meshes = #scene.meshes }
