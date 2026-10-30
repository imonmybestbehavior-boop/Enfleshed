-- Isolated review of existing artwork and motion; stop Play to remove it.
local rs=game:GetService("ReplicatedStorage")
local system=rs.Shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local spells=require(rs.Shared.Configuration.Spells)
renderer.stopAll()
local player=game:GetService("Players").LocalPlayer
for _,gui in player.PlayerGui:GetChildren() do if gui:IsA("ScreenGui") then gui.Enabled=false end end
local root=Instance.new("Folder");root.Name="FieldMotionVisualReview";root.Parent=workspace
local center=Vector3.new(10000,4,10000)
local ground=Instance.new("Part");ground.Anchored=true;ground.CanCollide=false
ground.Size=Vector3.new(70,1,60);ground.Position=center-Vector3.yAxis*4
ground.Material=Enum.Material.SmoothPlastic;ground.Color=Color3.fromRGB(47,58,66);ground.Parent=root
local light=game:GetService("Lighting");light.ClockTime=14;light.Brightness=2
light.Ambient=Color3.fromRGB(140,140,140);light.OutdoorAmbient=light.Ambient
for _,fx in light:GetChildren() do if fx:IsA("PostEffect") then fx.Enabled=false end end
local ruler=Instance.new("Part");ruler.Anchored=true;ruler.CanCollide=false;ruler.CanQuery=false
ruler.Size=Vector3.new(.3,5,.3);ruler.Position=center+Vector3.new(9,-1,0)
ruler.Color=Color3.fromRGB(180,190,190);ruler.Parent=root
local gui=Instance.new("ScreenGui");gui.Name="FieldMotionControls";gui.IgnoreGuiInset=true;gui.Parent=player.PlayerGui
local title=Instance.new("TextLabel");title.Size=UDim2.new(1,0,0,38);title.Position=UDim2.fromOffset(0,45)
title.TextColor3=Color3.new(1,1,1);title.BackgroundColor3=Color3.fromRGB(20,25,32);title.TextSize=22;title.Parent=gui
local anchor,session
local function show(identity,form)
 if session then session:Stop() end;if anchor then anchor:Destroy() end
 anchor=Instance.new("Part");anchor.Anchored=true;anchor.Transparency=1;anchor.CanCollide=false
 anchor.CanQuery=false;anchor.CanTouch=false;anchor.Size=if form=="Beam" then Vector3.new(1.4,1.4,24) else Vector3.new(14,8,14)
 anchor.CFrame=if form=="Beam" then CFrame.lookAt(center-Vector3.xAxis*12,center) else CFrame.new(center)
 anchor:SetAttribute("VFXPhase","Sustain");anchor.Parent=root
 local plan=table.clone(analyzer.resolve(spells.LightningLance));plan.Form=form or "Field"
 plan.Element=identity;plan.Expression=identity;plan.Principle=identity
 session=assert(renderer.attach(anchor,plan,{Parent=root,Quality="High"}))
 title.Text=identity.." / "..plan.Form.."    |    marker = 5 studs"
 return renderer.stats()
end
local choices={{"Fire","Field"},{"Water","Field"},{"Lightning","Field"},{"Ice","Field"},{"Arcane","Field"},
 {"Spirit","Field"},{"Space","Field"},{"Wind","Field"},{"Spirit","Aura"},{"Arcane","Beam"},{"Time","Beam"},{"Space","Beam"}}
for i,choice in choices do
 local button=Instance.new("TextButton");button.Size=UDim2.fromOffset(140,31)
 button.Position=UDim2.fromOffset(12,86+(i-1)*33);button.Text=choice[1].." "..choice[2]
 button.BackgroundColor3=Color3.fromRGB(28,37,46);button.TextColor3=Color3.new(1,1,1);button.TextSize=16;button.Parent=gui
 button.Activated:Connect(function() show(choice[1],choice[2]) end)
end
local remote=Instance.new("BindableFunction");remote.Name="Select";remote.Parent=root
remote.OnInvoke=function(identity,form) return show(identity,form) end
local function camera()
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable;workspace.CurrentCamera.FieldOfView=52
 workspace.CurrentCamera.CFrame=CFrame.lookAt(center+Vector3.new(19,16,24),center-Vector3.yAxis*1)
end
camera();game:GetService("RunService"):BindToRenderStep("FieldMotionReviewCamera",Enum.RenderPriority.Last.Value,camera)
show("Fire","Field");task.wait(.8)
return game:GetService("HttpService"):JSONEncode({Review="Grounded elemental motion",Stats=renderer.stats()})
