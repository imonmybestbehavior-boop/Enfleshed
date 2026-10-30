local studio_baked_restyle_check=(function()
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local assets=require(system.Assets.VFXAssets)
local styled=require(system.Assets.StyledVFXManifest)
local manifest=require(system.Assets.VFXAssetManifest)
local renderer=require(system.Signature.SignatureRenderer)
local fire=require(system.Signature.ConnectedFire)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
assets.prefetch()
local count=0
for key,id in styled.Textures do
	local identity,name=string.match(key,"^([^/]+)/(.+)$")
	local texture,layout,custom,baked=assets.texture(name,identity)
	assert(texture==id and custom and baked,"Baked identity mismatch: "..key)
	assert(layout.Name==(manifest.Textures[name].Flipbook or "None"),"Atlas layout changed: "..key)
	count+=1
end
assert(count==91,"Missing baked texture variants")
local meshCount=0
for name in manifest.Meshes do
	assert(assets.hasCustomMesh(name),"Mesh missing: "..name)
	local part,custom=assets.acquireMesh(name)
	assert(custom and part:GetAttribute("VFXBakedColors"),"Mesh color flag missing: "..name)
	local id=part.MeshId
	assets.releaseMesh(part)
	local recycled=assets.acquireMesh(name)
	assert(recycled==part and recycled.MeshId==id,"Pool lost the baked mesh: "..name)
	assets.releaseMesh(recycled)
	meshCount+=1
end
assert(meshCount==60,"Missing baked meshes")
local test=Instance.new("Folder"); test.Name="BakedRestyleLifecycleCheck";test.Parent=workspace
local names={}
for name,definition in spells do
	if type(definition)=="table" and definition.Form then
		local plan=analyzer.resolve(definition)
		local anchor=Instance.new("Part");anchor.Name=name;anchor.Transparency=1;anchor.Anchored=true
		anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
		anchor.Size=Vector3.new(4,4,4);anchor.CFrame=CFrame.new(10000,8,10000);anchor.Parent=test
		workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame=CFrame.lookAt(anchor.Position+Vector3.new(12,8,20),anchor.Position)
		local session=renderer.attach(anchor,plan,{Parent=test})
		assert(session,"Missing representative spell session: "..name)
		if name=="Fireball" then assert(session.ConnectedFire,"Approved connected fireball was replaced") end
		if name=="LightningLance" then
			local arc
			for _,entry in session.Entries do
				assert(entry.Layer.Id~="Beam.Flow" and entry.Layer.Id~="Beam.Motes", "Lightning still emits travelling arcs")
				if entry.Arc then arc=entry.Arc end
			end
			assert(arc,"Lightning must use a connected bolt")
			for i=1,8 do
				local range=10+i*3
				arc:Update(range,1,i*.07,true,0)
				assert(arc.Points[1].Position==Vector3.zero,"Bolt origin drifted")
				assert(arc.Points[#arc.Points].Position==Vector3.new(0,0,-range),"Bolt endpoint drifted")
			end
		end
		task.wait(.12)
		session:Stop();anchor:Destroy()
		table.insert(names,name)
	end
end
task.wait(4)
local stats=renderer.stats()
assert(stats.Sessions==0 and stats.Emitters==0 and stats.Meshes==0 and stats.Lights==0 and stats.Trails==0 and stats.Rate==0,
	"Runtime lifecycle leaked ownership")
test:Destroy()
return game:GetService("HttpService"):JSONEncode({Textures=count,Meshes=meshCount,Spells=names,Cleanup=stats,
	ConnectedFire=fire.stats(),Scope="Cosmetic renderer, real spell definitions, identity/layout and pooling checks; no GPU performance claim"})

end)()
local studio_beam_stream_check=(function()
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local assets=require(system.Assets.VFXAssets)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
renderer.stopAll()
local root=Instance.new("Folder");root.Name="BeamStreamRegression";root.Parent=workspace
local point=Vector3.new(10000,10,10000)
workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
workspace.CurrentCamera.CFrame=CFrame.lookAt(point+Vector3.new(10,10,30),point)
local function anchor(phase)
	local p=Instance.new("Part");p.Anchored=true;p.Transparency=1;p.CanCollide=false
	p.CanTouch=false;p.CanQuery=false;p.Size=Vector3.new(1,1,24);p.CFrame=CFrame.new(point)
	p:SetAttribute("VFXPhase",phase or "Sustain");p.Parent=root;return p
end
local checked={}
for _,identity in {"Fire","Water","Space","Arcane"} do
	local plan=table.clone(analyzer.resolve(spells.LightningLance))
	plan.Element=identity;plan.Expression=identity;plan.Principle=if identity=="Space" then "Space" else "Energy"
	local p=anchor()
	local session=renderer.attach(p,plan,{Parent=root});assert(session,identity)
	task.wait(.18)
	local representation
	for _,entry in session.Entries do
		assert(not entry.Emitter,"Beam still launches individual sprites: "..identity)
		if entry.Stream then
			representation="Stream"
			local connectedBodies=0
			for _,r in entry.Stream.Ribbons do
				assert(r.Start.Position.Z==0 and r.End.Position.Z==-24,"Stream lost endpoints")
				if not r.Inner and not r.Detail then
					assert(r.Beam.Texture=="","Stream body depends on gapped artwork")
					connectedBodies+=1
				end
				assert(r.Beam.TextureSpeed>0 and not r.Beam.FaceCamera,"Stream should flow internally without billboard spin")
			end
			assert(connectedBodies>=2,"Stream must have a connected volume")
		elseif entry.PathGlyphs then
			representation="Stations"
			local glyphs=entry.PathGlyphs
			local positions={}
			for i,station in glyphs.Stations do
				positions[i]=station.Point.Position
				assert(station.Emitter.Speed.Max==0 and station.Emitter.RotSpeed.Max==0 and station.Emitter.LockedToPart,"Motif is moving")
				if identity=="Arcane" then
					assert(station.Frame and station.Frame.Texture==(assets.texture("rune_circle","Arcane")),"Rune enclosure missing")
					assert(station.Frame.Size.Keypoints[1].Value>station.Emitter.Size.Keypoints[1].Value,"Rune is not enclosed")
				end
			end
			task.wait(.18)
			for i,station in glyphs.Stations do assert(station.Point.Position==positions[i],"Glyph advected along the path") end
		end
	end
	assert(representation==(if identity=="Fire" or identity=="Water" then "Stream" else "Stations"))
	-- Move/resize immediately before Finish: delayed smoke must use the latest endpoint.
	p.CFrame=CFrame.new(point+Vector3.new(7,2,4))*CFrame.Angles(0,.6,0)
	p:SetAttribute("VFXSize",Vector3.new(1,1,30))
	local expected=p.CFrame:PointToWorldSpace(Vector3.new(0,0,-30))
	local before=#session.Entries
	session:Finish()
	local smoke=false
	for i=before+1,#session.Entries do
		local entry=session.Entries[i]
		if entry.Emitter then
			local parent=entry.Emitter.Parent
			local pos=if parent:IsA("Attachment") then parent.WorldPosition else parent.Position
			assert((pos-expected).Magnitude<.01,"Dissipation spawned at caster: "..identity)
			if string.find(entry.Layer.Id,"Smoke",1,true) then smoke=true end
		end
	end
	assert(smoke,"Missing endpoint smoke check")
	session:Stop();p:Destroy()
	local cue=anchor("Release");cue.Name="SpellReleaseComposition"
	local cuePlan=analyzer.forPhase(plan,"Release",cue.Name)
	local cast=renderer.attach(cue,cuePlan,{Parent=root});assert(cast and cast.Role=="Cast")
	local layers=#cast.Entries;cast:Finish()
	assert(#cast.Entries==layers,"Cast termination generated landing smoke")
	cast:Stop();cue:Destroy()
	table.insert(checked,identity)
end
root:Destroy()
local stats=renderer.stats()
assert(stats.Sessions==0 and stats.Emitters==0 and stats.Trails==0 and stats.Meshes==0 and stats.Rate==0,"Beam resources leaked")
return game:GetService("HttpService"):JSONEncode({Checked=checked,FixedStations=true,GeometricEnclosures=true,EndpointSmoke=true,Cleanup=stats})

end)()
local studio_beam_stream_visual=(function()
-- Isolated client review: no gameplay spells or server state are created.
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
renderer.stopAll()
local player=game:GetService("Players").LocalPlayer
for _,gui in player.PlayerGui:GetChildren() do if gui:IsA("ScreenGui") then gui.Enabled=false end end
local light=game:GetService("Lighting")
light.ClockTime=14;light.Brightness=2;light.Ambient=Color3.fromRGB(135,135,135);light.OutdoorAmbient=light.Ambient
local root=Instance.new("Folder");root.Name="BeamStreamVisualReview";root.Parent=workspace
local center=Vector3.new(10000,8,10000)
local floor=Instance.new("Part");floor.Anchored=true;floor.CanCollide=false;floor.Size=Vector3.new(70,1,60)
floor.Position=center-Vector3.new(0,5,0);floor.Material=Enum.Material.SmoothPlastic;floor.Color=Color3.fromRGB(55,64,73);floor.Parent=root
for i,identity in {"Fire","Water","Space","Arcane"} do
	local origin=center+Vector3.new(-12,0,(i-2.5)*7)
	local anchor=Instance.new("Part");anchor.Anchored=true;anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false
	anchor.Transparency=1;anchor.Size=Vector3.new(1.4,1.4,24);anchor.CFrame=CFrame.lookAt(origin,origin+Vector3.xAxis);anchor.Parent=root
	local plan=table.clone(analyzer.resolve(spells.LightningLance));plan.Element=identity;plan.Expression=identity
	plan.Principle=if identity=="Space" then "Space" else "Energy"
	assert(renderer.attach(anchor,plan,{Parent=root}),identity)
	local label=Instance.new("BillboardGui");label.Size=UDim2.fromOffset(130,35);label.StudsOffset=Vector3.new(-2,2,0);label.AlwaysOnTop=true;label.Parent=anchor
	local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.TextColor3=Color3.new(1,1,1);t.TextSize=20;t.Text=identity;t.Parent=label
end
local function camera()
	workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
	workspace.CurrentCamera.FieldOfView=52
	workspace.CurrentCamera.CFrame=CFrame.lookAt(center+Vector3.new(16,25,39),center)
end
camera()
game:GetService("RunService"):BindToRenderStep("BeamStreamReviewCamera",Enum.RenderPriority.Last.Value,camera)
task.wait(.8)
return game:GetService("HttpService"):JSONEncode({Review="Continuous streams and fixed geometric motifs",Stats=renderer.stats()})

end)()
return game:GetService("HttpService"):JSONEncode({Library=studio_baked_restyle_check,Check=studio_beam_stream_check,Visual=studio_beam_stream_visual})