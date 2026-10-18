--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)

-- Publish the complete client transport before requiring optional gameplay
-- services. The client launcher and editor must never wait on map generation.
local remotes = Shared:FindFirstChild(Protocol.Folder)
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = Protocol.Folder
	remotes.Parent = Shared
end
for _, name in
	{
		Protocol.Request,
		Protocol.Feedback,
		Protocol.AerialControl,
		"MagicLabRequest",
		"MagicLabResponse",
		"GrimoireResponse",
		"TrainingDummyRequest",
		"TrainingDummyResponse",
		"MagicPresentation",
		"SpellVFX",
		"MissionRemote",
		Protocol.Inventory,
	}
do
	if not remotes:FindFirstChild(name) then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
	end
end

local function startService(name: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(string.format("Combat sandbox service %s failed to start: %s", name, tostring(err)))
	end
end

startService("FeatureFlagService", function()
	require(script.Services.FeatureFlagService).start()
end)
startService("TelemetryService", function()
	require(script.Services.TelemetryService).start()
end)
startService("PlayerProfileService", function()
	require(script.Services.PlayerProfileService).start()
end)
startService("EnemyRuntime", function()
	require(script.Services.EnemyRuntime).start()
end)
startService("ActionRouter", function()
	require(script.Networking.ActionRouter).start()
end)

startService("DefendTheWallsService", function()
	require(script.Services.DefendTheWallsService).start()
end)
startService("CombatSandboxService", function()
	require(script.Services.CombatSandboxService).start()
end)
