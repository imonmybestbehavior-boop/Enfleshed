local run=game:GetService("RunService")
local g=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
local viewport=g:FindFirstChildOfClass("ViewportFrame")
local clone=viewport:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
local mesh=clone.ConnectedFireVolume
local camera=workspace.CurrentCamera
local saved={CFrame=camera.CFrame,CameraType=camera.CameraType,FieldOfView=camera.FieldOfView}
clone.Parent=workspace
clone:PivotTo(CFrame.new(0,10000,0)*clone:GetPivot().Rotation)
local texture=mesh:FindFirstChildOfClass("SurfaceAppearance") or g.SurfaceFramePool:FindFirstChild("Frame_007")
if texture then texture.Parent=mesh end
viewport.BackgroundTransparency=1
viewport.CurrentCamera=nil
local target=mesh.Root.WorldCFrame.Position+Vector3.new(-.8,0,0)
camera.CameraType=Enum.CameraType.Scriptable
camera.FieldOfView=38
run:BindToRenderStep("ConnectedFireV4WorldCamera",Enum.RenderPriority.Camera.Value+10,function()
    camera.CFrame=CFrame.lookAt(target+Vector3.new(0,1.1,7),target)
end)
g.Destroying:Connect(function()
    run:UnbindFromRenderStep("ConnectedFireV4WorldCamera")
    camera.CameraType=saved.CameraType;camera.CFrame=saved.CFrame;camera.FieldOfView=saved.FieldOfView
    clone:Destroy()
end)
task.wait(.5)
return "Moved only the client test clone into an isolated world view; camera restores on Close test"
