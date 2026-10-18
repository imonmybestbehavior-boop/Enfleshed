-- Studio Command Bar (Play mode, client): reports which generated VFX assets are live.
-- Lists manifest entries without uploaded ids, preloads the uploaded ones and reports
-- failures, and checks ReplicatedStorage.VFXAssets.Meshes for imported MeshParts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local System = ReplicatedStorage.Shared.SpellVFXSystem
local Manifest = require(System.Assets.VFXAssetManifest)
local Assets = require(System.Assets.VFXAssets)
local missing, ids, names = {}, {}, {}
for name, entry in pairs(Manifest.Textures) do
	if entry.Id then
		table.insert(ids, entry.Id)
		names[entry.Id] = name
	else
		table.insert(missing, "texture " .. name)
	end
end
local folder = ReplicatedStorage:FindFirstChild("VFXAssets")
local meshes = folder and folder:FindFirstChild("Meshes")
for name, entry in pairs(Manifest.Meshes) do
	local imported = meshes and meshes:FindFirstChild(name)
	if not (imported and imported:IsA("MeshPart")) and not entry.Id then
		table.insert(missing, "mesh " .. name)
	end
end
local failed = {}
ContentProvider:PreloadAsync(ids, function(content, status)
	if status ~= Enum.AssetFetchStatus.Success then
		table.insert(failed, (names[content] or content) .. " (" .. status.Name .. ")")
	end
end)
Assets.prefetch()
task.wait(2)
local custom = 0
for name in pairs(Manifest.Meshes) do
	custom += if Assets.hasCustomMesh(name) then 1 else 0
end
print(string.format("[VFX assets] textures with ids: %d, failed loads: %d, meshes available: %d", #ids, #failed, custom))
for _, line in failed do
	warn("[VFX assets] failed: " .. line)
end
for _, line in missing do
	print("[VFX assets] not uploaded/imported (fallback in use): " .. line)
end
