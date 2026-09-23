import {it,expect} from 'bun:test';
import {readFileSync,rmSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {validateBytes} from 'gltf-validator';
import type {RunFn} from './pkgTests.js';

export function sceneNativeMotion(run:RunFn) {
 it('scene: native Motor6D and AnimationConstraint clips use engine easing, preserve pivots and leave the source untouched',async()=>{
  const path=`rodeo-test-native-${randomUUID()}.glb`;
  try {
   const result=await run({showReturn:true,source:`
local r=require('@rodeo/roblox')
local rig=Instance.new('Model');rig.Name='Rig';rig.Parent=workspace
local root=Instance.new('Part');root.Name='Root';root.CFrame=CFrame.new(10,2,3);root.Anchored=true;root.Parent=rig;rig.PrimaryPart=root
root.PivotOffset=CFrame.new(.2,.3,.4)
local child=Instance.new('Part');child.Name='Child';child.Anchored=true;child.Parent=rig;child.Size=Vector3.new(2,3,4);child.PivotOffset=CFrame.new(-.5,.2,.1)
local joint=Instance.new('Motor6D');joint.Part0=root;joint.Part1=child;joint.C0=CFrame.new(0,2,0);joint.C1=CFrame.new(.1,.5,0);joint.Parent=root
local leaf=Instance.new('Part');leaf.Name='Leaf';leaf.Anchored=true;leaf.Parent=rig
local a=Instance.new('Attachment');a.CFrame=CFrame.new(0,2,0);a.Parent=child
local b=Instance.new('Attachment');b.CFrame=CFrame.new(0,-1,0);b.Parent=leaf
local constraint=Instance.new('AnimationConstraint');constraint.Attachment0=a;constraint.Attachment1=b;constraint.IsKinematic=true;constraint.Parent=child
local controller=Instance.new('AnimationController');controller.Parent=rig
local animator=Instance.new('Animator');animator.Parent=controller
local clip=Instance.new('KeyframeSequence');clip.Name='Ease';clip.Loop=false;clip.Priority=Enum.AnimationPriority.Action2
for _,i in {0,.1,.3,1} do
 local key=Instance.new('Keyframe');key.Time=i;key.Parent=clip
 if i==1 then local marker=Instance.new('KeyframeMarker');marker.Name='Done';marker.Value='left';marker.Parent=key end
 local p=Instance.new('Pose');p.Name='Root';p.Weight=0;p.Parent=key
 local q=Instance.new('Pose');q.Name='Child';q.CFrame=CFrame.new(i*4,0,0)*CFrame.Angles(0,0,i*1.5);q.EasingStyle=Enum.PoseEasingStyle.Cubic;q.EasingDirection=Enum.PoseEasingDirection.In;q.Parent=p
 local v=Instance.new('Pose');v.Name='Leaf';v.CFrame=CFrame.new(0,i*2,0);v.Parent=q
end
local animation=Instance.new('Animation');animation.AnimationId=game:GetService('AnimationClipProvider'):RegisterAnimationClip(clip)
local track=animator:LoadAnimation(animation);track.Looped=false;track:Play(0,1,0)
local deadline=os.clock()+5;while track.Length==0 and os.clock()<deadline do task.wait() end;assert(track.Length>0)
track.TimePosition=.5;animator:StepAnimations(0)
local expected=root.PivotOffset:Inverse()*joint.C0*joint.Transform*joint.C1:Inverse()*child.PivotOffset
local expectedLeaf=child.PivotOffset:Inverse()*a.CFrame*constraint.Transform*b.CFrame:Inverse()
assert(math.abs(constraint.Transform.Y-1)<.001,'engine constraint fixture did not animate')
track:Stop(0);track:Destroy();animation:Destroy()
joint.Transform=CFrame.new(9,8,7);local before=joint.Transform;local originalFrame=child.CFrame
local warnings=r.exportEditableScene('${path}',{rig},{animationClips={{rig=rig,clip=clip}}})
assert(joint.Transform==before and child.CFrame==originalFrame,'export mutated source pose')
assert(#rig:GetChildren()==4,'export leaked a clone into source')
assert(string.find(table.concat(warnings,';'),'full rig poses'))
local copy=r.importEditableScene('${path}')
local metadata=copy.animations[1].metadata
assert(metadata.loop==false and metadata.priority=='Action2' and metadata.sampleRate==60)
assert(copy.animations[1].clip.Priority==Enum.AnimationPriority.Action2 and not copy.animations[1].clip.Loop)
local function check(name,expected)
 for _,channel in copy.animations[1].channels do
  if channel.node.Name==name and channel.path=='translation' then
   local index=table.find(channel.times,.5);assert(index)
   local offset=(index-1)*3
   local actual=Vector3.new(channel.values[offset+1],channel.values[offset+2],channel.values[offset+3])
   assert((actual-expected.Position).Magnitude<1e-4,name..' easing/pivot mismatch: '..tostring(actual)..' / '..tostring(expected.Position))
  end
 end
end
check('Child',expected);check('Leaf',expectedLeaf)
r.exportEditableScene('${path}',copy)
for _,o in copy.roots do o:Destroy() end;for _,o in copy.meshes do o:Destroy() end
rig:Destroy();clip:Destroy();return true
`});expect(result.ok,result.output).toBe(true);
   const bytes=readFileSync(path),doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
   expect(doc.animations[0].extras.rodeo).toEqual({loop:false,priority:'Action2',sampleRate:60,markers:[{time:1,name:'Done',value:'left'}]});
   expect(doc.accessors[doc.animations[0].samplers[0].input].count).toBe(61);
   const report=await validateBytes(new Uint8Array(bytes));expect(report.issues.numErrors,JSON.stringify(report.issues)).toBe(0);
  }finally{rmSync(path,{force:true});}
 });
 it('scene: native CurveAnimation drives skinned Bones and rejects ambiguous or incomplete rigs before replacing output',async()=>{
  const path=`rodeo-test-native-skin-${randomUUID()}.glb`;
  try {
   const result=await run({showReturn:true,source:`
local r=require('@rodeo/roblox');local fs=require('@rodeo/fs');local stream=require('@rodeo/stream')
local scene=r.importEditableScene('tests/fixtures/pkg/scenes/animated-skin.gltf')
local rig=scene.roots[1];local clip=scene.animations[1].clip
-- Authored fractional keys must deduplicate against 60 Hz samples after
-- conversion to glTF float32 timestamps, for curve clips as well as poses.
for _,curve in clip:GetDescendants() do
 if curve:IsA('FloatCurve') then
  curve:InsertKey(FloatCurveKey.new(.1,0,Enum.KeyInterpolationMode.Linear))
  curve:InsertKey(FloatCurveKey.new(.3,.2,Enum.KeyInterpolationMode.Linear));break
 end
end
local options={animationClips={{rig=rig,clip=clip}}}
r.exportEditableScene('${path}',{rig},options)
local function read() local h=fs.open('${path}','r');local b=buffer.tostring(stream.readBytes(h));stream.close(h);return b end
local before=read()
local bone=scene.sourceMap.joints[2][1].bone;bone.Archivable=false
local ok,err=pcall(r.exportEditableScene,'${path}',{rig},options)
assert(not ok and string.find(tostring(err),'Archivable'));assert(read()==before,'failed export replaced destination')
bone.Archivable=true
local copy=r.importEditableScene('${path}')
assert(#copy.animations==1 and #copy.animations[1].channels>0)
local found=false
for _,binding in copy.sourceMap.primitives do if #binding.mesh:GetBones()>0 then found=true end end
assert(found,'native export dropped mesh skin')
bone:Destroy()
ok,err=pcall(r.exportEditableScene,'${path}',{rig},options)
assert(not ok and string.find(tostring(err),'live Bone'));assert(read()==before,'incomplete skin export replaced destination')
for _,s in {copy,scene} do for _,o in s.roots do o:Destroy() end;for _,o in s.meshes do o:Destroy() end end
return true
`});expect(result.ok,result.output).toBe(true);
   const bytes=readFileSync(path),doc=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)));
   expect(doc.skins.length).toBeGreaterThan(0);
   const animated=new Set(doc.animations[0].channels.map((c:any)=>c.target.node));
   expect(doc.skins.some((s:any)=>s.joints.some((n:number)=>animated.has(n)))).toBe(true);
   const report=await validateBytes(new Uint8Array(bytes));expect(report.issues.numErrors,JSON.stringify(report.issues)).toBe(0);
  }finally{rmSync(path,{force:true});}
 });

 it('scene: single-key native poses export without waiting for a zero-length track',async()=>{
  const path=`rodeo-test-native-static-${randomUUID()}.glb`;
  try {
   const result=await run({showReturn:true,source:`
local r=require('@rodeo/roblox')
local rig=Instance.new('Model');local root=Instance.new('Part');root.Name='Root';root.Parent=rig;rig.PrimaryPart=root
local part=Instance.new('Part');part.Name='Child';part.Parent=rig
local motor=Instance.new('Motor6D');motor.Part0=root;motor.Part1=part;motor.Parent=root
local clips={}
local sequence=Instance.new('KeyframeSequence');table.insert(clips,sequence)
local key=Instance.new('Keyframe');key.Parent=sequence
local a=Instance.new('Pose');a.Name='Root';a.Weight=0;a.Parent=key
local b=Instance.new('Pose');b.Name='Child';b.CFrame=CFrame.new(3,0,0);b.Parent=a
local curve=Instance.new('CurveAnimation');table.insert(clips,curve)
local folder=Instance.new('Folder');folder.Name='Root';folder.Parent=curve
local child=Instance.new('Folder');child.Name='Child';child.Parent=folder
local position=Instance.new('Vector3Curve');position.Name='Position';position.Parent=child
position:X():InsertKey(FloatCurveKey.new(0,3,Enum.KeyInterpolationMode.Constant))
local rotation=Instance.new('RotationCurve');rotation.Name='Rotation';rotation.Parent=child
rotation:InsertKey(RotationCurveKey.new(0,CFrame.Angles(0,.3,0),Enum.KeyInterpolationMode.Constant))
for _,clip in clips do
 r.exportEditableScene('${path}',{rig},{animationClips={{rig=rig,clip=clip}}})
 local scene=r.importEditableScene('${path}')
 local found=false
 for _,channel in scene.animations[1].channels do if channel.path=='translation' then assert(#channel.times==1 and math.abs(channel.values[1]-3)<1e-4);found=true end end
 assert(found)
 for _,o in scene.roots do o:Destroy() end;for _,o in scene.meshes do o:Destroy() end
 clip:Destroy()
end
rig:Destroy();return true
`});expect(result.ok,result.output).toBe(true);
  }finally{rmSync(path,{force:true});}
 });

}
