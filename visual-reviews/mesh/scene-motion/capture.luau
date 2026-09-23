-- @rodeo run --place --port 46140
local r=require('@rodeo/roblox')
local assets=game:GetService('AssetService')
local lighting=game:GetService('Lighting')
lighting.ClockTime=13;lighting.Brightness=2;lighting.Ambient=Color3.fromRGB(150,150,150)
local camera={viewportSize=Vector2.new(1200,700),fov=40,cframe=CFrame.lookAt(Vector3.new(16,5,30),Vector3.new(16,3,0)),settle=.5}
local directory='visual-reviews/mesh/scene-motion/'
local rough=assert(assets:CreateEditableImage({Size=Vector2.one}))
rough:WritePixelsBuffer(Vector2.zero,Vector2.one,buffer.fromstring(string.char(255,255,255,255)))
local metal=assert(assets:CreateEditableImage({Size=Vector2.one}))
metal:WritePixelsBuffer(Vector2.zero,Vector2.one,buffer.fromstring(string.char(0,0,0,255)))
local baseline=Instance.new('Model')
local meshes,parts={},{}
for i,weights in {{.25,.5},{.75,0}} do
 local mesh=assert(assets:CreateEditableMesh());table.insert(meshes,mesh)
 local points={Vector3.zero,Vector3.new(2+weights[2],0,0),Vector3.new(0,2+2*weights[1],0)}
 local vertices={};for j,p in points do vertices[j]=mesh:AddVertex(p) end
 local normals={mesh:AddNormal(Vector3.zAxis),mesh:AddNormal((Vector3.zAxis+Vector3.new(0,.2,-.02)*weights[1]).Unit),mesh:AddNormal(Vector3.zAxis)}
 local f=mesh:AddTriangle(unpack(vertices));mesh:SetFaceNormals(f,normals)
 local part=assets:CreateMeshPartAsync(Content.fromObject(mesh),{CollisionFidelity=Enum.CollisionFidelity.Box})
 part.Anchored=true;part.DoubleSided=true;part.Material=Enum.Material.SmoothPlastic
 local origin=CFrame.new(if i==1 then 10 else 18,0,0)
 part.Size*=2;part.CFrame=origin*CFrame.new(mesh:GetCenter()*2);part.PivotOffset=part.CFrame:ToObjectSpace(origin)
 local appearance=Instance.new('SurfaceAppearance');appearance.Color=Color3.new(.12,.55,.9)
 appearance.AlphaMode=Enum.AlphaMode.Transparency;appearance.RoughnessMapContent=Content.fromObject(rough);appearance.MetalnessMapContent=Content.fromObject(metal);appearance.Parent=part
 part.Color=appearance.Color;part.Parent=baseline;parts[i]=part
end
baseline.Parent=workspace
r.captureViewport(directory..'baseline-initial.png',camera)
parts[1]:PivotTo(CFrame.new(10,2,0))
parts[2]:PivotTo(CFrame.new(18,0,0)*CFrame.Angles(0,0,.4))
r.captureViewport(directory..'baseline-motion.png',camera)
baseline.Parent=nil
local scene=r.importEditableScene('tests/fixtures/pkg/scenes/motion.gltf')
assert(scene.animations[1].sequence,table.concat(scene.warnings,'; '))
scene.animationRig.Parent=workspace
r.captureViewport(directory..'current-initial.png',camera)
local track=scene.animator:LoadAnimation(scene.animations[1].animation)
local deadline=os.clock()+5;while track.Length==0 and os.clock()<deadline do task.wait() end;assert(track.Length>0)
track:Play(0,1,0);track.TimePosition=.5;scene.animator:StepAnimations(0)
r.captureViewport(directory..'current-motion.png',camera)
local moving=scene.sourceMap.nodes[1]:GetPivot()
local rotating=scene.sourceMap.nodes[2]:GetPivot()
track:Stop(0);track:Destroy()
for _,root in scene.roots do root:Destroy() end
for _,mesh in scene.meshes do mesh:Destroy() end
for _,image in scene.images do image:Destroy() end
baseline:Destroy();for _,mesh in meshes do mesh:Destroy() end;rough:Destroy();metal:Destroy()
return {moving={moving:GetComponents()},rotating={rotating:GetComponents()},warnings=scene.warnings}
