local r=require("@rodeo/roblox")
local directory="visual-reviews/mesh/native-primitives"
local lighting=game:GetService("Lighting")
lighting.ClockTime=14;lighting.Ambient=Color3.fromRGB(100,100,100);lighting.OutdoorAmbient=lighting.Ambient
for _,view in {"native","legacy"} do
 local root=Instance.new("Model");root.Name=view;root.Parent=workspace
 local kinds=if view=="native" then {"Block","Ball","Cylinder","WedgePart","CornerWedgePart"} else {"Brick","Sphere","Cylinder"}
 for i,kind in kinds do
  local p=Instance.new(if view=="native" and i>=4 then kind else "Part")
  if view=="native" and i<4 then p.Shape=Enum.PartType[kind] end
  if view=="legacy" then local m=Instance.new("SpecialMesh");m.MeshType=Enum.MeshType[kind];m.Parent=p end
  p.Name=kind;p.Size=Vector3.new(3,4,5);p.Anchored=true;p.Color=Color3.fromRGB(80+i*25,170,210);p.Material=Enum.Material.SmoothPlastic
  p.CFrame=CFrame.new((i-1)*6,2,0);p.Parent=root
 end
 local focus=Vector3.new((#kinds-1)*3,2,0)
 local options={cframe=CFrame.lookAt(focus+Vector3.new(19,15,26),focus),fov=45,viewportSize=Vector2.new(1200,700),settle=1}
 r.exportEditableScene(directory.."/"..view..".glb",{root})
 r.captureViewport(directory.."/"..view.."-baseline.png",options)
 root:Destroy()
 local scene=r.importEditableScene(directory.."/"..view..".glb")
 scene.roots[1].Parent=workspace
 r.captureViewport(directory.."/"..view.."-current.png",options)
 for _,v in scene.roots do v:Destroy() end
 for _,v in scene.meshes do v:Destroy() end
end
return true
