import {it,expect} from "bun:test";
import {readFileSync,rmSync} from "node:fs";
import {randomUUID} from "node:crypto";
import {validateBytes} from "gltf-validator";
import type {RunFn} from "./pkgTests.js";

export function sceneExport(run: RunFn) {
 it("scene: all native primitives match engine surfaces and export valid triangles",async()=>{
  const path=`rodeo-test-primitives-${randomUUID()}.glb`;
  try {
   const result=await run({showReturn:true,source:`
local r=require("@rodeo/roblox")
local root=Instance.new("Model");root.Parent=workspace
local originals={}
for i,kind in {"Block","Ball","Cylinder","WedgePart","CornerWedgePart"} do
 local p=Instance.new(if i<4 then "Part" else kind)
 if i<4 then p.Shape=Enum.PartType[kind] end
 p.Name=kind;p.Size=Vector3.new(4,6,8);p.Anchored=true;p.Parent=root
 p.CFrame=CFrame.new(i*12,8,0);originals[kind]=p
end
task.wait() -- let Studio update the newly positioned native collision shapes
r.exportEditableScene("${path}",{root})
local s=r.importEditableScene("${path}")
for _,binding in s.sourceMap.primitives do
 local mesh,part=binding.mesh,binding.part
 local original=originals[part.Name]
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={original}
 local size=mesh:GetSize();local scale=part.Size/size
 for _,face in mesh:GetFaces() do
  local ids=mesh:GetFaceVertices(face)
  local a,b,c=mesh:GetPosition(ids[1]),mesh:GetPosition(ids[2]),mesh:GetPosition(ids[3])
  local cross=(b-a):Cross(c-a);assert(cross.Magnitude>1e-8,"degenerate primitive triangle")
  local normal=(cross.Unit/scale).Unit
  local center=(a+b+c)/3*scale
  local world=part.CFrame:PointToWorldSpace(center)
  local direction=part.CFrame:VectorToWorldSpace(normal)
  -- CornerWedgePart raycasts mishandle negative zero on parallel axes.
  local function rayAxis(value) return if value == 0 then 0 else -value*20 end
  local delta=Vector3.new(rayAxis(direction.X),rayAxis(direction.Y),rayAxis(direction.Z))
  local hit=workspace:Raycast(world+direction*10,delta,params)
  assert(hit and (hit.Position-world).Magnitude<.09,part.Name.." differs from engine surface: "..tostring(center).." normal "..tostring(direction).." hit "..tostring(hit and (hit.Position-world)).." pivot "..tostring(part.Position-original.Position).." size "..tostring(part.Size).." world "..tostring(world).." frame "..tostring(part.CFrame).." original "..tostring(original.CFrame))
 end
end
for _,v in s.roots do v:Destroy() end
for _,v in s.meshes do v:Destroy() end
root:Destroy();return "native surfaces matched"
`});expect(result.ok,result.output).toBe(true);
   const report=await validateBytes(new Uint8Array(readFileSync(path)));
   expect(report.issues.numErrors,JSON.stringify(report.issues)).toBe(0);
  }finally{rmSync(path,{force:true});}
 });
 it("scene: original image files and native emission/transmission export through the shared codec",async()=>{
  const id=randomUUID(),path=`rodeo-test-material-${id}.glb`,png=`rodeo-test-image-${id}.png`;
  try {
   const result=await run({showReturn:true,source:`
local r=require("@rodeo/roblox")
local a=game:GetService("AssetService")
local preview=a:CreateEditableImage({Size=Vector2.new(2,2)})
preview:DrawRectangle(Vector2.zero,Vector2.new(2,2),Color3.new(.25,.5,.75),0,Enum.ImageCombineType.Overwrite)
r.exportEditableImage("${png}",preview)
local root=Instance.new("Model")
for i,kind in {"Neon","Glass","ForceField"} do
 local p=Instance.new("Part");p.Name=kind;p.Material=Enum.Material[kind];p.Parent=root;p.CFrame=CFrame.new(i*5,0,0)
end
local m=a:CreateEditableMesh();local x=m:AddVertex(Vector3.zero);local y=m:AddVertex(Vector3.xAxis);local z=m:AddVertex(Vector3.yAxis);m:AddTriangle(x,y,z)
local part=a:CreateMeshPartAsync(Content.fromObject(m));part.Parent=root
local sa=Instance.new("SurfaceAppearance");sa.AlphaMode=Enum.AlphaMode.Transparency;sa.ColorMapContent=Content.fromObject(preview);sa.Parent=part
r.exportEditableScene("${path}",{root},{imageSources={[preview]="${png}"}})
local scene=r.importEditableScene("${path}")
r.exportEditableScene("${path}",scene)
for _,v in scene.roots do v:Destroy() end
for _,v in scene.meshes do v:Destroy() end
for _,v in scene.images do v:Destroy() end
root:Destroy();m:Destroy();preview:Destroy();return true
`});expect(result.ok,result.output).toBe(true);
   const bytes=readFileSync(path),doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
   expect(doc.extensionsUsed).toEqual(["KHR_materials_emissive_strength","KHR_materials_transmission"]);
   expect(doc.materials.find((m:any)=>m.name==="Neon").extensions.KHR_materials_emissive_strength.emissiveStrength).toBe(3);
   expect(doc.materials.find((m:any)=>m.name==="Glass").extensions.KHR_materials_transmission.transmissionFactor).toBeCloseTo(.9);
   const report=await validateBytes(new Uint8Array(bytes));expect(report.issues.numErrors,JSON.stringify(report.issues)).toBe(0);
  }finally{rmSync(path,{force:true});rmSync(png,{force:true});}
 });
}
