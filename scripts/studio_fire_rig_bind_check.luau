local mesh = workspace.single_flame_transport.Flame_00
local result = {MeshFrame={mesh.CFrame:GetComponents()},RootFrame={mesh.Root.CFrame:GetComponents()},Bones={}}
for _, name in {"Flow_00","Flow_10","Flow_20"} do
	local bone = mesh.Root[name]
	table.insert(result.Bones,{Name=name,Frame={bone.CFrame:GetComponents()},Transform={bone.Transform:GetComponents()}})
end
return game:GetService("HttpService"):JSONEncode(result)
