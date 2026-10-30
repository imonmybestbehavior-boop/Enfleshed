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
	if identity=="Space" then assert(not smoke,"Void closure should not explode into smoke") else assert(smoke,"Missing endpoint smoke check") end
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
