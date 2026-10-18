local playerGui=game:GetService("Players").LocalPlayer.PlayerGui
local old=playerGui:FindFirstChild("ConnectedFireV4Review")
if old then old:Destroy() end
local gui=Instance.new("ScreenGui");gui.Name="ConnectedFireV4StaticCompare";gui.DisplayOrder=20000;gui.IgnoreGuiInset=true
local source=game:GetService("ReplicatedStorage").ConnectedFireV4ImportClone
local bank=game:GetService("ReplicatedStorage").ConnectedFireV4Study
local results={}
for index,frame in {0,1,7} do
    local view=Instance.new("ViewportFrame");view.Size=UDim2.fromScale(1/3,1);view.Position=UDim2.fromScale((index-1)/3,0)
    view.BackgroundColor3=Color3.fromRGB(40,42,47);view.Ambient=Color3.new(1,1,1);view.LightColor=Color3.new(0,0,0);view.Parent=gui
    local world=Instance.new("WorldModel");world.Parent=view
    local clone=source:Clone();local mesh=clone.ConnectedFireVolume
    for _, child in clone:GetDescendants() do
        if child:IsA("BasePart") then child.Anchored=true;child.CanCollide=false end
        if child:IsA("Bone") then child.Transform=CFrame.identity end
    end
    if frame>0 then
        for _,child in mesh:GetChildren() do if child:IsA("SurfaceAppearance") then child:Destroy() end end
        bank[string.format("Frame_%03d",frame)]:Clone().Parent=mesh
    end
    clone.Parent=world
    local target=mesh.Position
    local camera=Instance.new("Camera");camera.FieldOfView=38;camera.CFrame=CFrame.lookAt(target+Vector3.new(0,1,11),target)
    camera.Parent=view;view.CurrentCamera=camera
    local label=Instance.new("TextLabel");label.Size=UDim2.new(1,0,0,60);label.BackgroundTransparency=1;label.TextColor3=Color3.new(1,1,1);label.TextSize=20
    label.Text=if frame==0 then "Imported material" else "Surface frame "..frame;label.Parent=view
    local image=Instance.new("ImageLabel");image.Name="LoadCheck";image.Size=UDim2.fromOffset(200,100);image.Position=UDim2.new(.5,-100,1,-120)
    image.Image=mesh:FindFirstChildOfClass("SurfaceAppearance").ColorMap;image.Parent=view
    table.insert(results,{Frame=frame,Image=image})
end
gui.Parent=playerGui
task.wait(3)
local output={}
for _,entry in results do table.insert(output,{Frame=entry.Frame,ImageLoaded=entry.Image.IsLoaded,Image=entry.Image.Image}) end
return game:GetService("HttpService"):JSONEncode(output)
