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
