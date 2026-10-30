-- Isolated test resources only. Does not replace existing spell effects.
assert(not game:GetService("RunService"):IsRunning(), "Prepare frame bank in Edit mode")
local storage = game:GetService("ReplicatedStorage")
assert(not storage:FindFirstChild("ConnectedFireV4Study"), "Frame bank already exists; inspect before rerunning")
local ids = {
    "rbxassetid://86919925936984",
    "rbxassetid://126350447146341",
    "rbxassetid://116449719617566",
    "rbxassetid://125896010345257",
    "rbxassetid://70474943111810",
    "rbxassetid://114606059894640",
    "rbxassetid://111817040702677",
    "rbxassetid://93106702508065",
    "rbxassetid://84326234505465",
    "rbxassetid://80695034184756",
    "rbxassetid://95076690170847",
    "rbxassetid://104361458711225",
    "rbxassetid://103706615899184",
    "rbxassetid://82416400377612",
    "rbxassetid://93970472335462",
    "rbxassetid://109039328659609",
    "rbxassetid://81899287344776",
    "rbxassetid://114491517326705",
    "rbxassetid://131694853984077",
    "rbxassetid://96894639170312",
    "rbxassetid://106111274610525",
    "rbxassetid://107148062871913",
    "rbxassetid://116423773889873",
    "rbxassetid://88447397847891"
}
local statuses = {}
local fetchOK, fetchError = pcall(function()
    game:GetService("ContentProvider"):PreloadAsync(ids, function(id, status)
        table.insert(statuses, {Id=id, Status=status.Name})
    end)
end)
local bank = Instance.new("Folder")
bank.Name = "ConnectedFireV4Study"
bank:SetAttribute("Scope", "Isolated test assets; runtime integration pending")
bank:SetAttribute("TextureFPS", 12)
for index, id in ids do
    local surface = Instance.new("SurfaceAppearance")
    surface.Name = string.format("Frame_%03d", index)
    surface.AlphaMode = Enum.AlphaMode.Transparency
    surface.ColorMap = id -- Studio/plugin preparation only; never set by the gameplay loop.
    surface.Parent = bank
end
bank.Parent = storage
return game:GetService("HttpService"):JSONEncode({Bank=bank:GetFullName(), Frames=#bank:GetChildren(),
    FetchOK=fetchOK, FetchError=if fetchOK then nil else tostring(fetchError), Statuses=statuses,
    MeshImported=false, PlaybackVerified=false})
