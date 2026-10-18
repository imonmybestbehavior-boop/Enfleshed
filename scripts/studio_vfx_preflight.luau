-- Read-only Studio MCP inspection; does not require modules or alter the place.
local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
local system = shared and shared:FindFirstChild("SpellVFXSystem")
local imported = game:GetService("ReplicatedStorage"):FindFirstChild("VFXAssets")
local meshes = imported and imported:FindFirstChild("Meshes")
local result = {
	PlaceId = game.PlaceId,
	UniverseId = game.GameId,
	CreatorId = game.CreatorId,
	CreatorType = tostring(game.CreatorType),
	IsRunning = game:GetService("RunService"):IsRunning(),
	SharedPresent = shared ~= nil,
	VFXPresent = system ~= nil,
	ImportedMeshes = {},
	VFXModules = {},
}
if meshes then
	for _, item in meshes:GetChildren() do
		table.insert(result.ImportedMeshes, { Name = item.Name, ClassName = item.ClassName })
	end
end
if system then
	for _, item in system:GetDescendants() do
		if item:IsA("ModuleScript") then
			table.insert(result.VFXModules, { Path = item:GetFullName(), SourceLength = #item.Source })
		end
	end
end
local identityOK, identity = pcall(function()
	return game:GetService("StudioService"):GetUserId()
end)
result.StudioUserId = if identityOK then identity else nil
-- Availability only, not art acceptance. Use a bounded representative Fire set.
if system then
	local manifest = require(system.Assets.VFXAssetManifest)
	local ids, names = {}, {}
	for _, name in { "core_plasma", "flame_tongue", "trail_flame", "explosion_fire", "smoke_billow", "ember_streak", "rune_circle" } do
		local entry = manifest.Textures[name]
		if entry and entry.Id then
			table.insert(ids, entry.Id)
			names[entry.Id] = name
		end
	end
	result.FireTextureFetch = {}
	local preloadOK, preloadError = pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(ids, function(content, status)
			table.insert(result.FireTextureFetch, { Name = names[content] or content, Status = status.Name })
		end)
	end)
	result.PreloadOK = preloadOK
	result.PreloadError = if preloadOK then nil else tostring(preloadError)
	result.FireMeshes = {}
	for _, name in { "fire_core", "flame_shell", "energy_ribbon" } do
		local entry = manifest.Meshes[name]
		if entry and entry.Id then
			local ok, mesh = pcall(function()
				return game:GetService("AssetService"):CreateMeshPartAsync(entry.Id)
			end)
			table.insert(result.FireMeshes, { Name = name, Loaded = ok, Detail = if ok then tostring(mesh.Size) else tostring(mesh) })
			if ok then
				mesh:Destroy()
			end
		end
	end
end
return game:GetService("HttpService"):JSONEncode(result)
