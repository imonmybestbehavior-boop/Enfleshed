-- Read-only availability check of the prepared frame bank and any imported v4 mesh.
local bank = game:GetService("ReplicatedStorage"):FindFirstChild("ConnectedFireV4Study")
assert(bank, "Missing v4 frame bank")
local content = game:GetService("ContentProvider")
local statuses = {}
local ok, err = pcall(function()
    content:PreloadAsync(bank:GetChildren(), function(id, status)
        table.insert(statuses, {Id=id, Status=status.Name})
    end)
end)
local metadata = {}
for _, name in {"Frame_001", "Frame_012", "Frame_024"} do
    local id = tonumber(bank[name].ColorMap:match("%d+"))
    local infoOK, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(id, Enum.InfoType.Asset)
    end)
    table.insert(metadata, {Frame=name, OK=infoOK, AssetTypeId=if infoOK then info.AssetTypeId else nil,
        Error=if infoOK then nil else tostring(info)})
end
local meshes = {}
for _, instance in workspace:GetDescendants() do
    if instance:IsA("MeshPart") and instance.Name == "ConnectedFireVolume" then
        local bones = 0
        for _, child in instance:GetDescendants() do
            if child:IsA("Bone") then bones += 1 end
        end
        table.insert(meshes, {Path=instance:GetFullName(), MeshId=instance.MeshId,
            Size={instance.Size.X, instance.Size.Y, instance.Size.Z}, Bones=bones})
    end
end
return game:GetService("HttpService"):JSONEncode({FetchCallOK=ok, Error=if ok then nil else tostring(err),
    Statuses=statuses, Metadata=metadata, ImportedMeshes=meshes})
