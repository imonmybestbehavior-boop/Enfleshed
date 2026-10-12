--!strict
-- Isolated traversal harness: uses existing movement/combat/AI without city startup.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local corpseLifetime = 2
local Runtime = require(script.Services.EnemyRuntime)
Runtime.start()
require(script.Networking.ActionRouter).start()

local folder = Instance.new("Folder")
folder.Name = "KitBlockChaseTest"
folder.Parent = workspace
local handles: { any } = {}
local mode, lastUse = 0, -math.huge
local candidates = { Vector3.new(-38, 8, 8), Vector3.new(-46, 8, 8), Vector3.new(-54, 8, 8) }

local console = Instance.new("Part")
console.Name = "ChaseTestSwitch"
console.Anchored = true
console.CanCollide = false
console.CanQuery = false
console.Size = Vector3.new(1, 2, 0.5)
console.Position = Vector3.new(5, 3, 15)
console.Color = Color3.fromRGB(189, 146, 73)
console.Parent = folder
local prompt = Instance.new("ProximityPrompt")
prompt.ObjectText = "KIT BLOCK — OPTIONAL CHASE"
prompt.ActionText = "Start 1 Nascent"
prompt.KeyboardKeyCode = Enum.KeyCode.F
prompt.MaxActivationDistance = 10
prompt.RequiresLineOfSight = false
prompt.HoldDuration = 0.3
prompt.Parent = console

local function clear()
	for _, handle in handles do
		handle.Destroy()
	end
	table.clear(handles)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
	folder:SetAttribute("Living", 0)
end

-- EnemyRuntime retires dead AI handles but intentionally leaves corpse ownership
-- to its caller. Debris also covers a clear/restart while removal is pending.
local cleanupElapsed = 0
RunService.Heartbeat:Connect(function(delta)
	cleanupElapsed += delta
	if cleanupElapsed < 0.2 then
		return
	end
	cleanupElapsed = 0
	for i = #handles, 1, -1 do
		local handle = handles[i]
		if not handle.Model.Parent or not handle.IsAlive() then
			table.remove(handles, i)
			if handle.Model.Parent then
				Debris:AddItem(handle.Model, corpseLifetime)
			end
		end
	end
	folder:SetAttribute("Living", #handles)
end)

prompt.Triggered:Connect(function(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or (root.Position - console.Position).Magnitude > 12
		or os.clock() - lastUse < 2
	then
		return
	end
	lastUse = os.clock()
	clear()
	mode = (mode + 1) % 3
	local count = if mode == 1 then 1 elseif mode == 2 then 3 else 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.KitBlock }
	params.RespectCanCollide = true
	for i = 1, count do
		local hit = workspace:Raycast(candidates[i], Vector3.new(0, -16, 0), params)
		if not hit or hit.Normal.Y < 0.9 then
			warn("KitBlock: no safe ground at chase spawn " .. i)
			continue
		end
		local position = hit.Position + Vector3.new(0, 4.5, 0)
		local clearOfPlayers = true
		for _, other in Players:GetPlayers() do
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") and (otherRoot.Position - position).Magnitude < 8 then
				clearOfPlayers = false
			end
		end
		if clearOfPlayers then
			table.insert(handles, Runtime.create(position, folder))
		end
	end
	prompt.ActionText = if mode == 0
		then "Start 1 Nascent"
		elseif mode == 1 then "Restart with 3 Nascent"
		else "Clear enemies"
	folder:SetAttribute("Spawned", #handles)
end)
Players.PlayerRemoving:Connect(function()
	if #Players:GetPlayers() <= 1 then
		clear()
		mode = 0
		prompt.ActionText = "Start 1 Nascent"
	end
end)
print("KitBlock ready: explore first; use F at the brass switch beside spawn for an optional chase.")
