-- Inspect returned asset types and underlying image content without parenting assets.
local records = {
	{ Name = "front", Id = 81011468551955 },
	{ Name = "three_quarter", Id = 81316819745490 },
	{ Name = "side", Id = 97561699384624 },
	{ Name = "rear", Id = 92127109486544 },
}
local result = {}
for _, entry in records do
	local row = { Name = entry.Name, ReturnedId = entry.Id }
	local infoOK, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(entry.Id, Enum.InfoType.Asset)
	end)
	if infoOK then
		row.AssetTypeId = info.AssetTypeId
		row.AssetName = info.Name
		row.Creator = info.Creator
	else
		row.MetadataError = tostring(info)
	end
	local loadOK, model = pcall(function()
		return game:GetService("InsertService"):LoadAsset(entry.Id)
	end)
	if loadOK then
		row.Children = {}
		for _, item in model:GetDescendants() do
			local detail = { ClassName = item.ClassName, Name = item.Name }
			if item:IsA("Decal") or item:IsA("Texture") then
				detail.ImageContent = item.Texture
			end
			table.insert(row.Children, detail)
		end
		model:Destroy()
	else
		row.InsertError = tostring(model)
	end
	table.insert(result, row)
end
return game:GetService("HttpService"):JSONEncode(result)
