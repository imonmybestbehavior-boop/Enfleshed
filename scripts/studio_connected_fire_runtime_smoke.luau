local shared=game:GetService("ReplicatedStorage").Shared
local system=shared.SpellVFXSystem
local renderer=require(system.Signature.SignatureRenderer)
local fire=require(system.Signature.ConnectedFire)
local analyzer=require(system.Core.SpellVFXAnalyzer)
local run=game:GetService("RunService")
local player=game:GetService("Players").LocalPlayer
local previous=player.PlayerGui:FindFirstChild("ConnectedFireRuntimeReview")
if previous then previous:Destroy() end
local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
assert(root,"Wait for the player character")
assert(fire.ready(),"Packaged skin or surface frames unavailable")
local folder=Instance.new("Folder");folder.Name="ConnectedFireRuntimeTest";folder.Parent=workspace
local anchor=Instance.new("Part");anchor.Name="CosmeticProjectileTestAnchor";anchor.Anchored=true
anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Transparency=1;anchor.Size=Vector3.one*2.2
local center=root.Position+Vector3.new(0,5,-10)
anchor.CFrame=CFrame.lookAt(center,center+Vector3.new(0,0,-1));anchor.Parent=folder
local plan=analyzer.resolve(require(shared.Configuration.Spells).Fireball)
local session=renderer.attach(anchor,plan,{Parent=folder})
assert(session and session.ConnectedFire,"Fire projectile did not select the connected body")
local camera=workspace.CurrentCamera
local saved={CFrame=camera.CFrame,Type=camera.CameraType,FOV=camera.FieldOfView}
local gui=Instance.new("ScreenGui");gui.Name="ConnectedFireRuntimeReview";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=20000
local hidden={}
for _,item in player.PlayerGui:GetChildren() do
    if item:IsA("ScreenGui") then hidden[item]=item.Enabled;item.Enabled=false end
end
local label=Instance.new("TextLabel");label.Size=UDim2.new(1,-32,0,50);label.Position=UDim2.fromOffset(16,64)
label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1);label.TextSize=20;label.TextScaled=true
label.Text="Integrated projectile renderer · scene lighting";label.Parent=gui
local close=Instance.new("TextButton");close.Size=UDim2.fromOffset(150,42);close.Position=UDim2.new(0,16,1,-58)
close.Text="Close test";close.Parent=gui;close.Activated:Connect(function() gui:Destroy() end)
gui.Parent=player.PlayerGui
camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=60
camera.CFrame=CFrame.lookAt(center+Vector3.new(12,5,22),center)
local born=os.clock()
run:BindToRenderStep("ConnectedFireRuntimeCamera",Enum.RenderPriority.Last.Value,function()
    local t=os.clock()-born
    local pos=center+Vector3.new(math.sin(t*.7)*2,0,math.cos(t*.7)*2)
    local direction=Vector3.new(math.cos(t*.7),0,-math.sin(t*.7))
    anchor.CFrame=CFrame.lookAt(pos,pos+direction)
    camera.CFrame=CFrame.lookAt(pos+Vector3.new(12,5,22),pos)
end)
gui.Destroying:Connect(function()
    run:UnbindFromRenderStep("ConnectedFireRuntimeCamera")
    session:Stop();folder:Destroy()
    camera.CFrame=saved.CFrame;camera.CameraType=saved.Type;camera.FieldOfView=saved.FOV
    for item,enabled in hidden do if item.Parent then item.Enabled=enabled end end
end)
task.wait(2)
return game:GetService("HttpService"):JSONEncode({Fire=fire.stats(),Renderer=renderer.stats(),
    BodySize={session.ConnectedFire.Mesh.Size.X,session.ConnectedFire.Mesh.Size.Y,session.ConnectedFire.Mesh.Size.Z},
    RootPosition={session.ConnectedFire.Mesh.Root.WorldCFrame.Position.X,session.ConnectedFire.Mesh.Root.WorldCFrame.Position.Y,session.ConnectedFire.Mesh.Root.WorldCFrame.Position.Z},
    Scope="Production renderer on cosmetic moving anchor, existing scene lighting; not an actual cast"})
