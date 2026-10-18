-- Read-only discovery of the imported transport-study rig.
local results = {}
for _, instance in game:GetDescendants() do
	if instance:IsA("MeshPart") then
		local bones = {}
		for _, child in instance:GetDescendants() do
			if child:IsA("Bone") then table.insert(bones, {Name=child.Name, Parent=child.Parent.Name}) end
		end
		if #bones > 0 or string.find(string.lower(instance.Name), "flame") then
			table.insert(results, {Path=instance:GetFullName(), Name=instance.Name, MeshId=instance.MeshId,
				TextureID=instance.TextureID, Size={instance.Size.X,instance.Size.Y,instance.Size.Z}, Bones=bones})
		end
	end
end
return game:GetService("HttpService"):JSONEncode({IsRunning=game:GetService("RunService"):IsRunning(),Rigs=results})
