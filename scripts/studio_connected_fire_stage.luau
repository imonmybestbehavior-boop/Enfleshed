assert(game:GetService("RunService"):IsServer(), "Run on the test server")
local storage=game:GetService("ReplicatedStorage")
assert(not storage:FindFirstChild("ConnectedFireV4ImportClone"), "Test clone already staged")
local source=workspace.connected_fireball
local clone=source:Clone()
clone.Name="ConnectedFireV4ImportClone"
assert(clone:FindFirstChild("ConnectedFireVolume",true),"Server import missing mesh")
for _, child in clone:GetDescendants() do
    if child:IsA("BaseScript") then child:Destroy() end
end
clone.Parent=storage
return "Staged a playtest-only import clone outside Workspace streaming"
