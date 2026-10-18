-- Generated from the actual saved Studio upload receipt. Read-only fetch check.
local assets = {
	{ Name = "front", Id = "rbxassetid://81011468551955" },
	{ Name = "three_quarter", Id = "rbxassetid://81316819745490" },
	{ Name = "side", Id = "rbxassetid://97561699384624" },
	{ Name = "rear", Id = "rbxassetid://92127109486544" },
}
local ids, names, statuses = {}, {}, {}
for _, entry in assets do
	table.insert(ids, entry.Id)
	names[entry.Id] = entry.Name
end
local ok, err = pcall(function()
	game:GetService("ContentProvider"):PreloadAsync(ids, function(content, status)
		table.insert(statuses, { Name = names[content] or content, Content = content, Status = status.Name })
	end)
end)
local result = { PreloadOK = ok, Statuses = statuses, PlaceId = game.PlaceId, UniverseId = game.GameId, IsRunning = game:GetService("RunService"):IsRunning() }
if not ok then result.Error = tostring(err) end
local identityOK, identity = pcall(function() return game:GetService("StudioService"):GetUserId() end)
if identityOK then result.StudioUserId = identity end
return game:GetService("HttpService"):JSONEncode(result)
