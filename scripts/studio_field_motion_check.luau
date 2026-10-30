local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local composer=require(system.Core.SpellVFXComposer)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
renderer.stopAll()
local previous=workspace:FindFirstChild("FieldMotionRegression");if previous then previous:Destroy() end
local root=Instance.new("Folder");root.Name="FieldMotionRegression";root.Parent=workspace
local center=Vector3.new(10000,4,10000)
workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame=CFrame.lookAt(center+Vector3.new(16,18,28),center)
local ground=Instance.new("Part");ground.Anchored=true;ground.Size=Vector3.new(60,1,60)
ground.Position=center-Vector3.yAxis*4;ground.Parent=root
local function anchor(name,phase,size)
 local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.Transparency=1
 p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Size=size or Vector3.new(14,8,14)
 p.CFrame=CFrame.new(center);p:SetAttribute("VFXPhase",phase);p.Parent=root;return p
end
local releases=0
for _,quality in {"High","Low"} do
 for name,definition in spells do
  if type(definition)=="table" and definition.Form then
   for _,useSignature in {true,false} do
    local p=anchor("SpellReleaseComposition","Release")
    p.Parent=nil;analyzer.stamp(p,definition,p.Size,"Release")
    -- This test owns the client anchor; avoid a second controller attachment.
    game:GetService("CollectionService"):RemoveTag(p,"ComposedSpellVFX")
    p.Parent=root
    composer.Signatures=if useSignature then renderer else nil
    local session=assert(composer.attach(p,analyzer.read(p),{Parent=root,Quality=quality}),name)
    assert(#session.Render.Layers==0,"Release fallback spawned artwork: "..name)
    if session.Signature then
     assert(session.Signature.Role=="Cast",name)
     for _,e in session.Signature.Entries do assert(e.Layer.Kind=="Light","Cast explosion: "..name) end
     local count=#session.Signature.Entries
     session:Finish();assert(#session.Signature.Entries==count,"Release termination spawned smoke")
    end
    session:Stop();if session.Signature then session.Signature:Stop() end;p:Destroy();releases+=1
   end
  end
 end
end
composer.Signatures=renderer
assert(releases>0,"No real spell definitions checked")
local modes={Fire="Flames",Water="Ripples",Arcane="Runes",Lightning="Storm",Ice="Crystals",Spirit="Wisps",Space="Void",Wind="Gusts"}
local counts={}
for identity,mode in modes do
 local p=anchor("Field","Sustain")
 local plan=table.clone(analyzer.resolve(spells.LightningLance));plan.Form="Field";plan.Element=identity;plan.Expression=identity;plan.Principle=identity
 local session=assert(renderer.attach(p,plan,{Parent=root,Quality="High"}),identity)
 task.wait(.15)
 local d
 for _,e in session.Entries do if e.Dynamics then d=e.Dynamics end end
 assert(d and d.Mode==mode,identity.." missing motion mode")
 counts[identity]=#d.Nodes
 local sizes={};local positions={}
 for i,n in d.Nodes do
  if n.Card then
   sizes[i]=if n.Card.Ground then n.Part.Size else n.Card.Gui.Size;positions[i]=n.Part.Position
   assert(n.Card.Atlas.Image.Rotation==0,"Spinning illustration")
   if identity=="Arcane" or identity=="Water" then
    assert(n.Card.Ground and n.Card.Gui.Face==Enum.NormalId.Top,"Field card not on ground")
   end
  end
 end
 if identity=="Ice" then
  local variants={};for _,n in d.Nodes do variants[n.Part.MeshId]=true end
  local count=0;for _ in variants do count+=1 end;assert(count>=4,"Missing crystal variants")
 end
 task.wait(.18)
 if identity=="Spirit" then
  assert(d.Nodes[1].Part.Position.Y>positions[1].Y,"Spirit not rising")
  assert(d.Nodes[1].Card.Gui.Size==sizes[1],"Spirit grew while spawning")
 end
 session:Stop();p:Destroy()
end
for _,identity in {"Arcane","Time","Space","Fire","Water"} do
 local p=anchor("Beam","Sustain",Vector3.new(1.4,1.4,24))
 local plan=table.clone(analyzer.resolve(spells.LightningLance));plan.Element=identity;plan.Expression=identity;plan.Principle=identity
 local session=assert(renderer.attach(p,plan,{Parent=root}),identity)
 task.wait(.12)
 local stream,glyphs
 for _,e in session.Entries do if e.Stream then stream=e.Stream end;if e.PathGlyphs then glyphs=e.PathGlyphs end end
 if identity=="Arcane" or identity=="Time" or identity=="Space" then assert(glyphs,identity.." missing stations") end
 if identity~="Space" then assert(stream,identity.." missing continuous beam") end
 if identity=="Time" then assert(#glyphs.Stations==2,"Time requires two endpoint clocks") end
 -- Termination must snapshot the latest beam endpoint, even between render steps.
 p.CFrame=CFrame.new(center+Vector3.new(7,2,4))*CFrame.Angles(0,.6,0)
 p:SetAttribute("VFXSize",Vector3.new(1.4,1.4,30))
 local endpoint=p.CFrame:PointToWorldSpace(Vector3.new(0,0,-30))
 local before=#session.Entries;session:Finish();local smoke=0
 for i=before+1,#session.Entries do
  local e=session.Entries[i]
  if e.Emitter then
   local host=e.Emitter.Parent
   local position=if host:IsA("Attachment") then host.WorldPosition else host.Position
   assert((position-endpoint).Magnitude<.01,"Beam smoke at caster: "..identity);smoke+=1
  end
 end
 assert(smoke==0,"Beam teardown must not duplicate the hit cloud: "..identity)
 session:Stop();p:Destroy()
end
task.wait(.2)
root:Destroy()
local stats=renderer.stats()
assert(stats.Sessions==0 and stats.Emitters==0 and stats.Meshes==0 and stats.Trails==0 and stats.Rate==0,"Resources leaked")
return game:GetService("HttpService"):JSONEncode({ReleaseCases=releases,GroundedModes=counts,ConnectedBeams=true,Cleanup=stats})
