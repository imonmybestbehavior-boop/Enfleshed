local run=game:GetService("RunService")
local pg=game:GetService("Players").LocalPlayer.PlayerGui
for _,name in {"ConnectedFireV4Review","ConnectedFireV4StaticCompare"} do local old=pg:FindFirstChild(name);if old then old:Destroy() end end
local clone=game:GetService("ReplicatedStorage").ConnectedFireV4ImportClone:Clone()
clone.Name="ConnectedFireV4WorldPreview"
local mesh=clone.ConnectedFireVolume
for _,v in clone:GetDescendants() do
    if v:IsA("BasePart") then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false;v.LocalTransparencyModifier=0 end
    if v:IsA("Bone") then v.Transform=CFrame.identity end
end
clone.Parent=workspace
mesh.CFrame=CFrame.new(0,10000,0)
local camera=workspace.CurrentCamera
local saved={Type=camera.CameraType,CFrame=camera.CFrame,FOV=camera.FieldOfView}
local g=Instance.new("ScreenGui");g.Name="ConnectedFireV4WorldReview";g.DisplayOrder=30000;g.IgnoreGuiInset=true;g.ResetOnSpawn=false;g.Parent=pg
local label=Instance.new("TextLabel");label.Size=UDim2.new(1,0,0,70);label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1);label.Text="Fireball · actual world rendering";label.TextSize=24;label.Parent=g
camera.CameraType=Enum.CameraType.Scriptable;camera.FieldOfView=38
local target=mesh.Position
run:BindToRenderStep("ConnectedFireV4MainCamera",Enum.RenderPriority.Last.Value,function()
    camera.CFrame=CFrame.lookAt(target+Vector3.new(0,1,8),target)
end)
g.Destroying:Connect(function()
    run:UnbindFromRenderStep("ConnectedFireV4MainCamera")
    camera.CameraType=saved.Type;camera.CFrame=saved.CFrame;camera.FieldOfView=saved.FOV;clone:Destroy()
end)
task.wait(1)
return game:GetService("HttpService"):JSONEncode({Position={mesh.Position.X,mesh.Position.Y,mesh.Position.Z},Camera={camera.CFrame:GetComponents()}})
