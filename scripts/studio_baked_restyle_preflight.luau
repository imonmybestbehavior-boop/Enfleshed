local rs = game:GetService("ReplicatedStorage")
local system = rs.Shared.SpellVFXSystem
local out = { PlaceId=game.PlaceId, GameId=game.GameId, Sources={}, Meshes={} }
for _, rel in { {"Assets","VFXAssets"}, {"Signature","SignaturePlanner"}, {"Signature","SignatureRenderer"}, {"Signature","ConnectedFire"} } do
	local m = system[rel[1]][rel[2]]
	out.Sources[rel[1] .. "/" .. rel[2]] = m.Source
end
local assets = rs:FindFirstChild("VFXAssets")
local meshes = assets and assets:FindFirstChild("Meshes")
if meshes then
	for _, mesh in meshes:GetChildren() do
		table.insert(out.Meshes, {Name=mesh.Name, ClassName=mesh.ClassName})
	end
end
return game:GetService("HttpService"):JSONEncode(out)
