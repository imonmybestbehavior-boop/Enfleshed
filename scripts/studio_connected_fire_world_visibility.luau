local pg=game:GetService("Players").LocalPlayer.PlayerGui
local g=pg:FindFirstChild("ConnectedFireV4WorldReview")
local clone=workspace:FindFirstChild("ConnectedFireV4WorldPreview")
local mesh=clone and clone:FindFirstChild("ConnectedFireVolume")
local result={GuiExists=g~=nil,MeshExists=mesh~=nil}
if g then
    g:FindFirstChildOfClass("TextLabel").TextColor3=Color3.new(1,0,0)
    result.Enabled=g.Enabled
end
if mesh then
    result.Position={mesh.Position.X,mesh.Position.Y,mesh.Position.Z}
    result.Transparency=mesh.Transparency;result.LocalTransparency=mesh.LocalTransparencyModifier
    local surface=mesh:FindFirstChildOfClass("SurfaceAppearance")
    if surface then surface:Destroy() end
    mesh.Material=Enum.Material.Neon;mesh.Color=Color3.new(1,0,0)
    local marker=Instance.new("Part");marker.Name="ConnectedFireV4DiagnosticMarker";marker.Shape=Enum.PartType.Ball;marker.Size=Vector3.new(.5,.5,.5)
    marker.Anchored=true;marker.CanCollide=false;marker.Material=Enum.Material.Neon;marker.Color=Color3.new(0,1,0);marker.Position=mesh.Position+Vector3.new(0,2,0);marker.Parent=workspace
    g.Destroying:Connect(function() marker:Destroy() end)
end
return game:GetService("HttpService"):JSONEncode(result)
