local mesh = workspace.connected_fireball.ConnectedFireVolume
local result = {MeshFrame={mesh.CFrame:GetComponents()}, TextureID=mesh.TextureID, Bones={}, Surfaces={}}
for _, item in mesh:GetDescendants() do
    if item:IsA("Bone") then
        table.insert(result.Bones, {Name=item.Name, Parent=item.Parent.Name,
            Frame={item.CFrame:GetComponents()}, World={item.WorldCFrame:GetComponents()}})
    elseif item:IsA("SurfaceAppearance") then
        table.insert(result.Surfaces,{Name=item.Name, ColorMap=item.ColorMap, AlphaMode=item.AlphaMode.Name})
    end
end
return game:GetService("HttpService"):JSONEncode(result)
