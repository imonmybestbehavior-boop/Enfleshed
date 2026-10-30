local check=(function()
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
local visual=(function()
-- Local review fixture only; never saved into gameplay.
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local assets=require(system.Assets.VFXAssets)
local renderer=require(system.Signature.SignatureRenderer)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
renderer.stopAll()
game:GetService("RunService"):UnbindFromRenderStep("BakedRestyleReviewCamera")
local previous=workspace:FindFirstChild("BakedAssetVisualReview")
if previous then previous:Destroy() end
local player=game:GetService("Players").LocalPlayer
for _,gui in player.PlayerGui:GetChildren() do if gui:IsA("ScreenGui") then gui.Enabled=false end end
local lighting=game:GetService("Lighting")
lighting.ClockTime=14;lighting.Brightness=2;lighting.Ambient=Color3.fromRGB(130,130,130)
lighting.OutdoorAmbient=Color3.fromRGB(130,130,130)
local root=Instance.new("Folder");root.Name="BakedAssetVisualReview";root.Parent=workspace
local center=Vector3.new(10000,5,10000)
local function part(name,pos,size,color)
	local p=Instance.new("Part");p.Name=name;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
	p.Size=size;p.Position=pos;p.Material=Enum.Material.SmoothPlastic;p.Color=color;p.Parent=root;return p
end
part("ReviewFloor",center-Vector3.new(0,4.5,0),Vector3.new(70,1,50),Color3.fromRGB(65,71,79))
part("SixStudScale",center+Vector3.new(-13,-1,2),Vector3.new(1,6,1),Color3.fromRGB(185,190,190))
local function label(host,text)
	local gui=Instance.new("BillboardGui");gui.Size=UDim2.fromOffset(150,40);gui.StudsOffset=Vector3.new(0,4,0);gui.AlwaysOnTop=true;gui.Parent=host
	local t=Instance.new("TextLabel");t.Size=UDim2.fromScale(1,1);t.BackgroundTransparency=1;t.TextColor3=Color3.new(1,1,1);t.TextSize=18;t.Text=text;t.Parent=gui
end
local anchors={}
for i,name in {"Fireball","StoneShot","LightningLance"} do
	local p=part(name,center+Vector3.new((i-2)*9,0,0),if i==3 then Vector3.new(1,1,10) else Vector3.one*2.2,Color3.new())
	p.Transparency=1;p.CFrame=CFrame.lookAt(p.Position,p.Position+Vector3.new(-1,0,0))
	local session=renderer.attach(p,analyzer.resolve(spells[name]),{Parent=root})
	assert(session,name);label(p,name);table.insert(anchors,p)
end
local crystal=assets.acquireMesh("ice_cluster")
crystal.Color=Color3.new(1,1,1);crystal.Material=Enum.Material.SmoothPlastic;crystal.Transparency=0
assets.place(crystal,CFrame.new(center+Vector3.new(1,0,9)),assets.meshSize("ice_cluster")*2)
crystal.Parent=root;label(crystal,"Imported color bands")
local a=part("ExistingSoulWispAtlas",center+Vector3.new(10,-3,8),Vector3.one,Color3.new());a.Transparency=1
local emitter=Instance.new("ParticleEmitter")
local texture,layout=assets.texture("soul_wisp","Spirit")
emitter.Texture=texture;emitter.FlipbookLayout=layout;emitter.FlipbookMode=Enum.ParticleFlipbookMode.Loop
emitter.FlipbookFramerate=NumberRange.new(16);emitter.Color=ColorSequence.new(Color3.new(1,1,1))
emitter.Size=NumberSequence.new(2);emitter.Lifetime=NumberRange.new(2.5);emitter.Speed=NumberRange.new(2.5)
emitter.Rate=3;emitter.LightEmission=.15;emitter.LightInfluence=.25
emitter.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.7,0),NumberSequenceKeypoint.new(1,1)})
emitter.Parent=a;label(a,"Existing Soul wisp")
local camera=workspace.CurrentCamera
local function view()
	camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=55
	camera.CFrame=CFrame.lookAt(center+Vector3.new(22,16,38),center+Vector3.new(0,0,3))
end
view()
game:GetService("RunService"):BindToRenderStep("BakedRestyleReviewCamera",Enum.RenderPriority.Last.Value,view)
task.wait(3)
return game:GetService("HttpService"):JSONEncode({Fixture="Actual uploaded textures and imported mesh vertex colors",Renderer=renderer.stats()})

end)()
return game:GetService("HttpService"):JSONEncode({Check=check,Visual=visual})