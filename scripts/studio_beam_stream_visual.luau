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
