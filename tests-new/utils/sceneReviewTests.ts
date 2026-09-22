import { it, expect } from "bun:test";
import { readFileSync, writeFileSync, mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";
import { validateBytes } from "gltf-validator";
import type { RunFn } from "./pkgTests.js";

const fixture = "tests-new/fixtures/pkg/scenes/";
const cleanup = `local function destroy(scene)
 for _,root in scene.roots do root:Destroy() end
 for _,mesh in scene.meshes do mesh:Destroy() end
 for _,image in scene.images do image:Destroy() end
end`;

export function sceneReview(run: RunFn) {
  it("scene: attachment identity, clones and nonuniform parent sizes round trip without shear", async () => {
    const output=`rodeo-test-review-${randomUUID()}.glb`;
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local mesh=game:GetService("AssetService"):CreateEditableMesh()
        local a=mesh:AddVertex(Vector3.new(-1,-1,0));local b=mesh:AddVertex(Vector3.new(1,-1,0));local c=mesh:AddVertex(Vector3.new(0,1,0));mesh:AddTriangle(a,b,c)
        local part=game:GetService("AssetService"):CreateMeshPartAsync(Content.fromObject(mesh))
        part.Name="Scaled";part.Size=Vector3.new(4,2,.01);part.CFrame=CFrame.new(3,4,5)
        local attachment=Instance.new("Attachment");attachment.Name="Socket";attachment.Parent=part
        attachment.CFrame=CFrame.new(1,2,3)*CFrame.Angles(0,0,.7)
        local empty=Instance.new("Model");empty.Name="Ordinary empty";empty.WorldPivot=CFrame.new(8,9,10)*CFrame.Angles(.4,.3,.2);empty.Parent=part
        local expected=attachment.WorldCFrame
        r.exportEditableScene("${output}",{part})
        local scene=r.importEditableScene("${output}")
        assert(#scene.roots==1 and scene.roots[1]:IsA("Model"))
        local socket=scene.roots[1]:FindFirstChild("Socket",true)
        assert(socket:IsA("Attachment") and socket.Parent:IsA("MeshPart"),socket.ClassName.." under "..socket.Parent.ClassName)
        assert((socket.WorldCFrame.Position-expected.Position).Magnitude<1e-4,tostring(socket.WorldCFrame).." expected "..tostring(expected))
        assert(socket.WorldCFrame.XVector:Dot(expected.XVector)>.99999,"attachment orientation changed")
        assert(scene.roots[1]:FindFirstChild("Ordinary empty",true):IsA("Model"))
        local clone=scene.roots[1]:Clone();clone.Name="Clone"
        assert(clone:FindFirstChild("Scaled",true):GetAttribute("RodeoSceneWorldScale"))
        r.exportEditableScene("${output}",{clone})
        clone:Destroy();destroy(scene);part:Destroy();mesh:Destroy()
        return "attachments and clones passed"
      `});expect(result.ok,result.output).toBe(true);
      const resultDoc=await validateBytes(new Uint8Array(readFileSync(output)));
      expect(resultDoc.issues.numErrors,JSON.stringify(resultDoc.issues)).toBe(0);
    } finally { rmSync(output,{force:true}); }
  });

  it("scene: untextured factors preserve vertex colors without images and native materials retain identity",async()=>{
    const output=`rodeo-test-material-${randomUUID()}.gltf`;
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local s=r.importEditableScene("${fixture}motion.gltf")
        assert(#s.images==0 and #s.sourceMap.materials[0]==2)
        for _,binding in s.sourceMap.primitives do assert(not binding.part:FindFirstChildOfClass("SurfaceAppearance")) end
        assert(#s.morphs==1 and s.sourceMap.primitives[1].mesh==s.sourceMap.primitives[2].mesh)
        local mesh=s.morphs[1].mesh
        local normalId=mesh:GetNormals()[1];mesh:SetNormal(normalId,Vector3.new(.6,0,.8))
        local red=mesh:AddColor(Color3.new(1,0,0),1)
        for _,face in mesh:GetFaces() do mesh:SetFaceColors(face,{red,red,red}) end
        r.exportEditableScene("${output}",s)
        local copy=r.importEditableScene("${output}")
        local edited=copy.morphs[1].mesh
        local face=edited:GetFaces()[1]
        assert((edited:GetNormal(edited:GetFaceNormals(face)[1])-Vector3.new(.6,0,.8)).Magnitude<.001,"normal edit did not remain base data")
        assert(edited:GetColor(edited:GetFaceColors(face)[1])==Color3.new(1,0,0),"vertex colors changed")
        destroy(copy);destroy(s)
        return "untextured factors passed"
      `});expect(result.ok,result.output).toBe(true);
      const doc=JSON.parse(readFileSync(output,"utf8"));
      expect(doc.images).toBeUndefined();
      expect(doc.materials[0].pbrMetallicRoughness.roughnessFactor).toBe(1);
      expect(doc.materials[0].pbrMetallicRoughness.metallicFactor).toBe(0);
      const native=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local part=Instance.new("Part");part.Material=Enum.Material.WoodPlanks
        assert(#r.exportEditableScene("${output}",{part},{strict=true})==0)
        local s=r.importEditableScene("${output}",{strict=true})
        assert(s.sourceMap.primitives[1].part.Material==Enum.Material.WoodPlanks)
        destroy(s);part:Destroy();return "native identity passed"
      `});expect(native.ok,native.output).toBe(true);
    } finally { rmSync(output,{force:true}); }
  });

  it("scene: strict failures preserve files and warnings aggregate by feature",async()=>{
    const output=`rodeo-test-strict-${randomUUID()}.glb`;
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");local fs=require("@rodeo/fs");local stream=require("@rodeo/stream");${cleanup}
        local root=Instance.new("Model")
        for i=1,20 do local p=Instance.new("Part");p.Material=Enum.Material.Neon;p.Name="Part"..i;p.Parent=root end
        local warnings=r.exportEditableScene("${output}",{root})
        assert(#warnings==1 and string.find(warnings[1],"20 occurrences"),table.concat(warnings,";"))
        local function bytes() local h=fs.open("${output}","r");local b=stream.readBytes(h);stream.close(h);return buffer.tostring(b) end
        local before=bytes()
        local ok,err=pcall(r.exportEditableScene,"${output}",{root},{strict=true})
        assert(not ok and string.find(tostring(err),"Neon"));assert(bytes()==before)
        ok,err=pcall(r.importEditableScene,"${fixture}motion.gltf",{strict=true})
        assert(not ok and string.find(tostring(err),"preview"))
        -- Host encoding fails after the stream was populated. Neither normal
        -- codec failure nor repeated failure may commit the wire packet.
        local s=r.importEditableScene("${fixture}motion.gltf")
        s.animations[1].channels[1].times[2]=0
        for i=1,3 do ok=pcall(r.exportEditableScene,"${output}",s);assert(not ok and bytes()==before) end
        destroy(s);root:Destroy();return "strict and atomic failure passed"
      `});expect(result.ok,result.output).toBe(true);
    } finally { rmSync(output,{force:true}); }
  });

  it("scene: exact native cubic translation keeps source keys and tangents",async()=>{
    const result=await run({showReturn:true,source:`
      local r=require("@rodeo/roblox");${cleanup}
      local s=r.importEditableScene("${fixture}motion.gltf")
      local native=assert(s.animations[1].clip,table.concat(s.warnings,";"))
      assert(native:IsA("CurveAnimation"))
      local channel=s.animations[1].channels[1]
      local curve=native:FindFirstChild("__RodeoNode2",true):FindFirstChild("Position"):Y()
      local keys=curve:GetKeys();assert(#keys==#channel.times,"cubic translation was resampled")
      assert(keys[1].Interpolation==Enum.KeyInterpolationMode.Cubic)
      assert(math.abs(curve:GetValueAtTime(.5)-2)<.001,"cubic tangent conversion changed interpolation")
      assert(not pcall(r.importEditableScene,"${fixture}motion.gltf",{animationRig=false}))
      destroy(s);return "exact native curves passed"
    `});expect(result.ok,result.output).toBe(true);
  });

  it("scene: composed bone STEP curves do not become interpolation ramps",async()=>{
    const input=`rodeo-test-composed-${randomUUID()}.gltf`;
    const doc=JSON.parse(readFileSync(fixture+"animated-skin.gltf","utf8"));
    doc.nodes.push({name:"Animated non-joint group",children:[1]});
    doc.nodes[0].children=[4,3];
    doc.animations[0].channels[1].target.node=4;
    writeFileSync(input,JSON.stringify(doc));
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local s=r.importEditableScene("${input}");s.roots[1].Parent=workspace
        local clip=s.animations[1];assert(clip.clip,table.concat(s.warnings,";"))
        local track=s.animator:LoadAnimation(clip.animation)
        local deadline=os.clock()+5;while track.Length==0 and os.clock()<deadline do task.wait() end
        assert(track.Length>0);track:Play(0,1,0)
        local bone=s.sourceMap.joints[1][1].bone
        track.TimePosition=.5;s.animator:StepAnimations(0)
        assert(bone.Transform.XVector:Dot(Vector3.xAxis)>.99999,"composed STEP ramped early")
        track.TimePosition=1.5;s.animator:StepAnimations(0)
        assert(math.abs(bone.Transform.XVector.X-math.cos(.6))<.001,"composed STEP lost its second pose")
        track:Stop();track:Destroy();destroy(s);return "composed STEP passed"
      `});expect(result.ok,result.output).toBe(true);
    } finally {rmSync(input,{force:true});}
  });

  it("scene: unsupported Attachment playback warns without losing portable channels",async()=>{
    const input=`rodeo-test-attachment-motion-${randomUUID()}.gltf`;
    const output=`rodeo-test-attachment-motion-${randomUUID()}.glb`;
    const doc=JSON.parse(readFileSync(fixture+"motion.gltf","utf8"));
    doc.nodes.push({name:"Moving socket",extras:{rodeo:{class:"Attachment"}}});
    doc.nodes[1].children=[3];
    doc.animations[0].channels[0].target.node=3;
    writeFileSync(input,JSON.stringify(doc));
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local s=r.importEditableScene("${input}")
        assert(s.animations[1].channels[1].node:IsA("Attachment"),"source target class")
        assert(not s.animations[1].clip and not s.animations[1].animation,"unsupported native clip was generated")
        assert(string.find(table.concat(s.warnings,";"),"Attachment-targeted animation",1,true),table.concat(s.warnings,";"))
        r.exportEditableScene("${output}",s)
        local copy=r.importEditableScene("${output}")
        local found=false;for _,channel in copy.animations[1].channels do if channel.path=="translation" then found=channel.node:IsA("Attachment") end end;assert(found,"roundtrip target class")
        destroy(copy);destroy(s);return "unsupported playback reported"
      `});expect(result.ok,result.output).toBe(true);
      const checked=await validateBytes(new Uint8Array(readFileSync(output)));
      expect(checked.issues.numErrors,JSON.stringify(checked.issues)).toBe(0);
    } finally {rmSync(input,{force:true});rmSync(output,{force:true});}
  });

  const names=["Box","BoxTextured","RiggedSimple","CesiumMan","AnimatedMorphCube","InterpolationTest","BoxAnimated"];
  for (const name of names) it(`scene: Khronos ${name} imports, exports and passes the independent validator`,async()=>{
    const retained=process.env.RODEO_SCENE_REVIEW_DIR;
    const dir=retained || mkdtempSync(join(tmpdir(),"rodeo-khronos-"));mkdirSync(dir,{recursive:true});
    const output=join(dir,name+".glb");
    try {
      const result=await run({showReturn:true,source:`
        local r=require("@rodeo/roblox");${cleanup}
        local s=r.importEditableScene("${fixture}khronos/${name}.glb")
        assert(#s.roots==1 and s.roots[1]:IsA("Model"))
        assert(#s.sourceMap.primitives>0)
        for _,clip in s.animations do
          local transforms=false
          for _,channel in clip.channels do if channel.path=="translation" or channel.path=="rotation" then transforms=true end end
          if transforms then assert(clip.clip and clip.clip:IsA("CurveAnimation"),table.concat(s.warnings,";")) end
        end
        r.exportEditableScene(${JSON.stringify(output)},s)
        local copy=r.importEditableScene(${JSON.stringify(output)})
        assert(#copy.sourceMap.primitives==#s.sourceMap.primitives)
        assert(#copy.animations==#s.animations)
        assert(copy.roots[1].Name==s.roots[1].Name)
        r.exportEditableScene(${JSON.stringify(output)},copy)
        destroy(copy);destroy(s);return "${name} passed"
      `});expect(result.ok,result.output).toBe(true);
      const checked=await validateBytes(new Uint8Array(readFileSync(output)));
      expect(checked.issues.numErrors,JSON.stringify(checked.issues)).toBe(0);
    } finally { if(!retained) rmSync(dir,{recursive:true,force:true}); }
  });
}
