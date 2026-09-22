import { sceneReview } from "./sceneReviewTests.js";
import { it, expect } from "bun:test";
import { readFileSync, rmSync } from "node:fs";
import { randomUUID } from "node:crypto";
import type { RunFn } from "./pkgTests.js";

const fixture = "tests-new/fixtures/pkg/scenes/";
const cleanup = `local function destroy(scene)
  for _, root in scene.roots do root:Destroy() end
  for _, mesh in scene.meshes do mesh:Destroy() end
  for _, image in scene.images do image:Destroy() end
end`;

export function scenes(run: RunFn): void {
  sceneReview(run);
  it("scene: exact curves and sparse morphs survive live edits, corner splits and repeated exports", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.gltf`;
    try {
      const result = await run({ showReturn: true, source: `
        local r=require("@rodeo/roblox")
        ${cleanup}
        local scene=r.importEditableScene("${fixture}motion.gltf")
        assert(#scene.animations==4 and #scene.animations[1].channels==4)
        assert(#scene.morphs==1 and #scene.morphWeights==2)
        assert(scene.sourceMap.primitives[1].mesh==scene.sourceMap.primitives[2].mesh,"different weights must share the unposed base mesh")
        local morph=scene.morphs[1]
        assert(morph.targets[1].name=="Tall" and morph.targets[2].name=="Wide")
        local vertices=morph.mesh:GetVertices()
        assert(math.abs(morph.mesh:GetPosition(vertices[3]).Y-2)<0.001,"unposed morph base")
        assert(math.abs(scene.morphs[1].mesh:GetSize().Y-2)<0.001)
        morph.mesh:SetPosition(vertices[1],morph.mesh:GetPosition(vertices[1])+Vector3.new(.125,0,0))
        local face=morph.mesh:AddTriangle(vertices[1],vertices[2],vertices[3])
        local original=morph.mesh:GetFaces()[1]
        morph.mesh:SetFaceNormals(face,morph.mesh:GetFaceNormals(original))
        morph.mesh:SetFaceUVs(face,{morph.mesh:AddUV(Vector2.zero),morph.mesh:AddUV(Vector2.xAxis),morph.mesh:AddUV(Vector2.yAxis)})
        scene.animations[1].channels[1].values[8]=5 -- first cubic out-tangent Y
        r.exportEditableScene("${output}",scene)
        local copy=r.importEditableScene("${output}")
        assert(#copy.animations[1].channels==4 and copy.animations[1].channels[1].values[8]==5)
        local deltaCount=0;for _ in copy.morphs[1].targets[1].positions do deltaCount+=1 end
        assert(deltaCount==6,"morph deltas must follow the split face-corner tuples")
        local found=false
        for _,id in copy.morphs[1].mesh:GetVertices() do if math.abs(copy.morphs[1].mesh:GetPosition(id).X-.125)<.001 then found=true end end
        assert(found,"live base position edit survived default-pose removal")
        assert(math.abs(copy.sourceMap.nodes[0]:GetPivot().X-10)<.001)
        copy.sourceMap.nodes[0]:ScaleTo(2)
        r.exportEditableScene("${output}",copy)
        destroy(copy);destroy(scene)
        return "motion roundtrip passed"
      ` });
      expect(result.ok, result.output).toBe(true);
      const doc = JSON.parse(readFileSync(output, "utf8"));
      expect(doc.nodes.length).toBe(5); // resized meshes have separate geometry frames
      expect(doc.nodes[0].matrix[0]).toBe(4);
      expect(doc.animations[0].samplers.map((s: any) => s.interpolation)).toEqual(["CUBICSPLINE","LINEAR","STEP","LINEAR"]);
      expect(doc.meshes[0].extras.targetNames).toEqual(["Tall","Wide"]);
    } finally { rmSync(output,{force:true}); }
  });

  it("scene: procedural roots can supply portable animation channels",async()=>{
    const output=`rodeo-test-scene-${randomUUID()}.glb`;
    try{
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox")
        ${cleanup}
        local part=Instance.new("Part");part.Name="Moving box";part.Anchored=true;part.Size=Vector3.new(2,3,4)
        local clip={name="Move",channels={{node=part,path="translation",interpolation="LINEAR",times={0,1},values={0,0,0,4,0,0}}}}
        r.exportEditableScene("${output}",{roots={part},animations={clip}})
        local scene=r.importEditableScene("${output}")
        assert(scene.animations[1].clip,table.concat(scene.warnings,";"))
        assert(scene.animations[1].channels[1].node.Name=="Moving box")
        assert((scene.sourceMap.primitives[1].part.Size-part.Size).Magnitude<.001)
        destroy(scene);part:Destroy();return "procedural animation passed"
      `});expect(result.ok,result.output).toBe(true);
    }finally{rmSync(output,{force:true});}
  });

  it("scene: native clips animate node rigs and Bones while portable export omits generated helpers", async () => {
    const output=`rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox")
        ${cleanup}
        local scene=r.importEditableScene("${fixture}animated-skin.gltf")
        assert(scene.animationRig and scene.animator)
        local clip=scene.animations[1]
        assert(clip.clip and clip.animation,table.concat(scene.warnings,"; "))
        assert(clip.clip:IsA("CurveAnimation"))
        scene.animationRig.Parent=workspace
        local bone=scene.sourceMap.joints[2][1].bone
        local before=bone.Transform
        local track=scene.animator:LoadAnimation(clip.animation)
        local deadline=os.clock()+5;while track.Length==0 and os.clock()<deadline do task.wait() end
        assert(track.Length>0,"animation did not load")
        track:Play(0,1,0)
        track.TimePosition=.5
        scene.animator:StepAnimations(0)
        assert((bone.Transform.Position-before.Position).Magnitude>.4,"native Animator did not drive the imported Bone")
        local rootBone=scene.sourceMap.joints[1][1].bone
        assert(rootBone.Transform.XVector:Dot(Vector3.xAxis)>.99999,"STEP rotation interpolated before its next key")
        track:Stop(0);track:Destroy()
        r.exportEditableScene("${output}",scene)
        local copy=r.importEditableScene("${output}")
        assert(copy.animations[1].clip and #copy.animations[1].channels==2)
        local count=0;for _ in copy.sourceMap.nodes do count+=1 end;assert(count==4,"generated rig leaked into glTF")
        r.exportEditableScene("${output}",copy)
        local again=r.importEditableScene("${output}")
        count=0;for _ in again.sourceMap.nodes do count+=1 end;assert(count==4,"round trips grew the rig hierarchy")
        destroy(again);destroy(copy);destroy(scene)
        local moving=r.importEditableScene("${fixture}motion.gltf")
        assert(moving.animations[1].clip,table.concat(moving.warnings,"; "))
        assert(moving.animations[4].clip==nil,"morph-only clip must not pretend to animate native joints")
        for _,pose in moving.animations[3].clip:GetDescendants() do
          assert(not (pose:IsA("Folder") and pose.Name=="__RodeoNode3"),"independent clip overwrites another node")
        end
        moving.animationRig.Parent=workspace
        local motor
        for _,obj in moving.animationRig:GetDescendants() do
          if obj:IsA("Motor6D") and obj.Part1.Name=="__RodeoNode2" then motor=obj end
        end
        assert(motor)
        track=moving.animator:LoadAnimation(moving.animations[1].animation)
        deadline=os.clock()+5;while track.Length==0 and os.clock()<deadline do task.wait() end
        assert(track.Length>0,"animation did not load")
        track:Play(0,1,0);track.TimePosition=.5;moving.animator:StepAnimations(0)
        assert(math.abs(motor.Transform.Y-2)<.02,"cubic motion under scaled parent sampled incorrectly")
        track:Stop(0);track:Destroy();destroy(moving)
        return "native animation passed"
      `});
      expect(result.ok,result.output).toBe(true);
    }finally{rmSync(output,{force:true});}
  });

  it("scene: dropping sidecar data warns, invalid edits preserve the destination",async()=>{
    const output=`rodeo-test-scene-${randomUUID()}.glb`;
    try{
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");local fs=require("@rodeo/fs");local stream=require("@rodeo/stream")
        ${cleanup}
        local scene=r.importEditableScene("${fixture}motion.gltf")
        local warnings=r.exportEditableScene("${output}",scene.roots)
        assert(string.find(table.concat(warnings,";"),"full EditableScene"))
        local function bytes() local h=fs.open("${output}","r");local b=stream.readBytes(h);stream.close(h);return buffer.tostring(b) end
        local before=bytes()
        scene.animations[1].channels[1].times[2]=0
        local ok,err=pcall(r.exportEditableScene,"${output}",scene)
        assert(not ok and string.find(tostring(err),"increasing"));assert(bytes()==before)
        scene.animations[1].channels[1].times[2]=1
        scene.animations[1].channels[1].node=Instance.new("Model")
        ok,err=pcall(r.exportEditableScene,"${output}",scene)
        assert(not ok and string.find(tostring(err),"outside"));assert(bytes()==before)
        scene.animations[1].channels[1].node:Destroy()
        destroy(scene)
        return "motion validation passed"
      `});expect(result.ok,result.output).toBe(true);
    }finally{rmSync(output,{force:true});}
  });

  it("scene: hierarchy, primitive bindings, shared resources and live edits survive round trips", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.gltf`;
    try {
      const result = await run({ showReturn: true, source: `
        local r = require("@rodeo/roblox")
        ${cleanup}
        local scene = r.importEditableScene("${fixture}structured.gltf")
        assert(#scene.roots == 1 and scene.roots[1].Parent == nil)
        assert(#scene.meshes == 2 and #scene.sourceMap.primitives == 4)
        local first, second = scene.sourceMap.nodes[1], scene.sourceMap.nodes[3]
        assert(first.Parent == scene.sourceMap.nodes[0] and second.Parent.Name == "Group")
        local a, b = scene.sourceMap.primitives[1], scene.sourceMap.primitives[3]
        assert(a.mesh == b.mesh and a.meshIndex == 0 and a.primitiveIndex == 0)
        assert((a.part.CFrame.Position - Vector3.new(13,4,-2)).Magnitude < 0.001)
        assert((b.part.CFrame.Position - Vector3.new(16,9,-2)).Magnitude < 0.001)
        assert((b.part.Size / a.part.Size - Vector3.new(2,1,1)).Magnitude < 0.001)
        local image = scene.sourceMap.images[0][1]
        image:WritePixelsBuffer(Vector2.zero, Vector2.one, buffer.fromstring(string.char(12,34,56,255)))
        scene.roots[1]:PivotTo(scene.roots[1]:GetPivot() + Vector3.new(0,0,5))
        local before = a.part.CFrame
        r.exportEditableScene("${output}", scene.roots)
        local nextScene = r.importEditableScene("${output}")
        assert(#nextScene.sourceMap.primitives == 4)
        local part = nextScene.sourceMap.primitives[1].part
        assert((part.CFrame.Position-before.Position).Magnitude < 0.001)
        assert(nextScene.sourceMap.primitives[1].mesh == nextScene.sourceMap.primitives[3].mesh)
        local pixels = nextScene.images[1]:ReadPixelsBuffer(Vector2.zero,Vector2.one)
        assert(buffer.readu8(pixels,0)==12 and buffer.readu8(pixels,1)==34)
        r.exportEditableScene("${output}", nextScene.roots)
        destroy(nextScene); destroy(scene)
        return "scene roundtrip passed"
      ` });
      expect(result.ok, result.output).toBe(true);
      expect(result.output).toContain("scene roundtrip passed");
      const doc = JSON.parse(readFileSync(output, "utf8"));
      expect(doc.nodes.length).toBe(8); // four source nodes, four material primitives
      expect(doc.meshes.length).toBe(2);
    } finally { rmSync(output, { force: true }); }
  });

  it("scene: skins retain numeric joint mappings and current poses with duplicate names", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result = await run({ showReturn: true, source: `
        local r = require("@rodeo/roblox")
        ${cleanup}
        local scene = r.importEditableScene("${fixture}skin.gltf")
        local root, child = scene.sourceMap.joints[1][1], scene.sourceMap.joints[2][1]
        assert(child.bone.Parent == root.bone and child.bone.Name ~= root.bone.Name)
        assert(math.abs(child.bone.Transform.Position.Y-1)<0.001)
        child.bone.Transform = CFrame.new(0,2,0)
        local before = child.bone.TransformedWorldCFrame
        r.exportEditableScene("${output}",scene.roots)
        local nextScene = r.importEditableScene("${output}")
        local found
        for _, bindings in nextScene.sourceMap.joints do
          for _, binding in bindings do
            if binding.bone.Name == child.bone.Name then found=binding.bone end
          end
        end
        assert(found and (found.TransformedWorldCFrame.Position-before.Position).Magnitude < 0.001)
        local count=0;for _ in nextScene.sourceMap.nodes do count+=1 end;assert(count==4)
        destroy(nextScene); destroy(scene)
        return "skin roundtrip passed"
      ` });
      expect(result.ok, result.output).toBe(true);
      expect(result.output).toContain("skin roundtrip passed");
    } finally { rmSync(output, { force: true }); }
  });

  it("scene: exports procedural roots and rejects unsupported geometry without replacing output", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result = await run({ showReturn: true, source: `
        local r = require("@rodeo/roblox")
        local fs = require("@rodeo/fs")
        local stream = require("@rodeo/stream")
        ${cleanup}
        local root = Instance.new("Model")
        local part = Instance.new("Part");part.Anchored=true;part.Material=Enum.Material.SmoothPlastic
        part.CFrame=CFrame.new(8,9,10)*CFrame.Angles(0,0.4,0);part.Size=Vector3.new(2,3,4);part.Parent=root
        r.exportEditableScene("${output}",{root})
        local scene=r.importEditableScene("${output}")
        local imported=scene.sourceMap.primitives[1].part
        assert((imported.Position-part.Position).Magnitude<0.001)
        assert((imported.Size-part.Size).Magnitude<0.001)
        local geometry=scene.sourceMap.primitives[1].mesh
        for _,face in geometry:GetFaces() do
          local vs=geometry:GetFaceVertices(face)
          local a,b,c=geometry:GetPosition(vs[1]),geometry:GetPosition(vs[2]),geometry:GetPosition(vs[3])
          local normal=(b-a):Cross(c-a).Unit
          assert(normal:Dot((a+b+c)/3-geometry:GetCenter())>0,"box winding points inward")
          for _,n in geometry:GetFaceNormals(face) do assert(geometry:GetNormal(n):Dot(normal)>0.999) end
        end
        local h=fs.open("${output}","r");local before=stream.readBytes(h);stream.close(h)
        part.Shape=Enum.PartType.Ball
        local ok,err=pcall(r.exportEditableScene,"${output}",{root})
        assert(not ok and string.find(tostring(err),"unsupported geometry"))
        h=fs.open("${output}","r");local after=stream.readBytes(h);stream.close(h)
        assert(buffer.tostring(before)==buffer.tostring(after))
        local invalid=pcall(r.importEditableScene,"missing.obj");assert(not invalid)
        destroy(scene);root:Destroy()
        return "procedural export passed"
      ` });
      expect(result.ok, result.output).toBe(true);
    } finally { rmSync(output, { force: true }); }
  });
  it("scene: image payloads above 4 MiB use chunked transport", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result = await run({ showReturn: true, source: `
        local r=require("@rodeo/roblox")
        local assets=game:GetService("AssetService")
        ${cleanup}
        local image=assert(assets:CreateEditableImage({Size=Vector2.new(1024,1024)}))
        local pixels=buffer.create(1024*1024*4);buffer.fill(pixels,0,137)
        image:WritePixelsBuffer(Vector2.zero,image.Size,pixels)
        local mesh=assert(assets:CreateEditableMesh())
        local a=mesh:AddVertex(Vector3.zero);local b=mesh:AddVertex(Vector3.xAxis);local c=mesh:AddVertex(Vector3.yAxis)
        mesh:AddTriangle(a,b,c)
        local part=assets:CreateMeshPartAsync(Content.fromObject(mesh));part.Material=Enum.Material.SmoothPlastic
        local surface=Instance.new("SurfaceAppearance");surface.AlphaMode=Enum.AlphaMode.Transparency
        surface.ColorMapContent=Content.fromObject(image);surface.Parent=part
        r.exportEditableScene("${output}",{part})
        local scene=r.importEditableScene("${output}")
        local imported=scene.images[1]:ReadPixelsBuffer(Vector2.zero,scene.images[1].Size)
        assert(buffer.len(imported)==1024*1024*4 and buffer.readu8(imported,buffer.len(imported)-1)==137)
        destroy(scene);part:Destroy();mesh:Destroy();image:Destroy()
        return "large scene passed"
      ` });
      expect(result.ok, result.output).toBe(true);
    } finally { rmSync(output, { force: true }); }
  });

  it("scene: nested cloned skins with independent poses export independent skeletons", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result = await run({ showReturn: true, source: `
        local r=require("@rodeo/roblox")
        ${cleanup}
        local scene=r.importEditableScene("${fixture}skin.gltf")
        local original=scene.sourceMap.primitives[1].part
        local copy=original:Clone();copy.Name="Copy";copy.Parent=original
        copy.CFrame+=Vector3.new(10,0,0)
        local name=scene.sourceMap.joints[2][1].bone.Name
        local bone=copy:FindFirstChild(name,true);bone.Transform=CFrame.new(0,3,0)
        local expected=bone.TransformedWorldCFrame.Position
        r.exportEditableScene("${output}",scene.roots)
        local roundtrip=r.importEditableScene("${output}")
        local found
        for _,binding in roundtrip.sourceMap.primitives do
          if binding.part.Name=="Copy" then found=binding.part:FindFirstChild(name,true) end
        end
        assert(found and (found.TransformedWorldCFrame.Position-expected).Magnitude<0.001)
        destroy(roundtrip);destroy(scene)
        return "independent skins passed"
      ` });
      expect(result.ok, result.output).toBe(true);
    } finally { rmSync(output, { force: true }); }
  });

  it("scene: distinct frozen DataModel resources stay distinct on export", async () => {
    const output = `rodeo-test-scene-${randomUUID()}.glb`;
    try {
      const result = await run({ showReturn: true, source: `
        local r=require("@rodeo/roblox")
        local assets=game:GetService("AssetService")
        ${cleanup}
        local roots={}
        for i=1,2 do
          local mesh=assert(assets:CreateEditableMesh())
          local a=mesh:AddVertex(Vector3.zero);local b=mesh:AddVertex(Vector3.new(i,0,0));local c=mesh:AddVertex(Vector3.yAxis)
          mesh:AddTriangle(a,b,c)
          local status,content=assets:CreateDataModelContentAsync(Content.fromObject(mesh));assert(status==Enum.CreateContentResult.Success)
          local part=assets:CreateMeshPartAsync(content);mesh:Destroy()
          part.Name="Frozen"..i;part.Material=Enum.Material.SmoothPlastic
          local image=assert(assets:CreateEditableImage({Size=Vector2.one}))
          image:WritePixelsBuffer(Vector2.zero,Vector2.one,buffer.fromstring(string.char(80*i,0,0,255)))
          status,content=assets:CreateDataModelContentAsync(Content.fromObject(image));assert(status==Enum.CreateContentResult.Success)
          local surface=Instance.new("SurfaceAppearance");surface.AlphaMode=Enum.AlphaMode.Transparency
          surface.ColorMapContent=content;surface.Parent=part;image:Destroy()
          table.insert(roots,part)
        end
        r.exportEditableScene("${output}",roots)
        local scene=r.importEditableScene("${output}")
        assert(#scene.meshes==2 and math.abs(scene.meshes[1]:GetSize().X-scene.meshes[2]:GetSize().X)>0.9)
        local values={}
        for _,binding in scene.sourceMap.primitives do
          local map=binding.part:FindFirstChildOfClass("SurfaceAppearance").ColorMapContent.Object
          values[buffer.readu8(map:ReadPixelsBuffer(Vector2.zero,Vector2.one),0)]=true
        end
        assert(values[80] and values[160])
        destroy(scene);for _,root in roots do root:Destroy() end
        return "frozen content passed"
      ` });
      expect(result.ok, result.output).toBe(true);
    } finally { rmSync(output, { force: true }); }
  });

}
