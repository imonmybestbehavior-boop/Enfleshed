local gui=game:GetService("Players").LocalPlayer.PlayerGui.ConnectedFireV4Review
local viewport=gui:FindFirstChildOfClass("ViewportFrame")
local clone=viewport:FindFirstChildOfClass("WorldModel"):FindFirstChildOfClass("Model")
local mesh=clone:FindFirstChild("ConnectedFireVolume",true)
local surface=mesh:FindFirstChildOfClass("SurfaceAppearance")
local bones={}
for _, name in {"Flow_02_02","Flow_05_04","Flow_07_01"} do
    table.insert(bones,{Name=name, Transform={mesh.Root[name].Transform:GetComponents()}})
end
return game:GetService("HttpService"):JSONEncode({Attributes=gui:GetAttributes(),MeshId=mesh.MeshId,
    SurfaceName=surface and surface.Name,ColorMap=surface and surface.ColorMap,AlphaMode=surface and surface.AlphaMode.Name,
    Bones=bones,DoubleSided=mesh.DoubleSided,MeshTransparency=mesh.Transparency})
