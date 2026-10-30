local model=workspace:FindFirstChild("Enfleshed_Cel_Existing_Meshes")
assert(model,"Imported mesh library is missing")
local rows={}
for _, part in model:GetDescendants() do
	if part:IsA("MeshPart") then
		table.insert(rows,{Name=part.Name,MeshId=part.MeshId,Size={part.Size.X,part.Size.Y,part.Size.Z},TextureID=part.TextureID})
	end
end
return game:GetService("HttpService"):JSONEncode(rows)
