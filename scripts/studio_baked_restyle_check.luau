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
