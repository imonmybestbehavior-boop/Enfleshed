--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Topology = require(Shared.Configuration.PhaseATopology)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Config = require(Shared.Configuration.Navigation).Ambient
local Enemy = require(script.Parent.EnemyService)
local Runtime = require(script.Parent.EnemyRuntime)
local Spawn = require(script.Parent.WorldSpawnService)
local Ambient = {}

function Ambient.start()
	if not Config.Enabled then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "AmbientEnfleshed"
	folder.Parent = workspace
	local entries: { { Handle: Enemy.Handle, Candidate: string } } = {}
	local used: { [string]: number } = {}
	local nextSpawn, nextScan = 0, 0
	local function nearest(position: Vector3): number
		local result = math.huge
		for _, player in Players:GetPlayers() do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if player:GetAttribute("OpeningComplete") and root and root:IsA("BasePart") then
				result = math.min(result, (root.Position - position).Magnitude)
			end
		end
		return result
	end
	local function candidate(now: number): (string?, Vector3?)
		for offset = 1, #Topology.SpawnCandidates do
			local item = Topology.SpawnCandidates[(math.floor(now) + offset - 1) % #Topology.SpawnCandidates + 1]
			local position = (item.Position or Topology.Nodes[item.Node]) + item.Offset
			local distance = nearest(position)
			if
				Spawn.safe(position, Config.SafeZoneRadius)
				and distance >= Config.MinimumPlayerDistance
				and distance <= Config.MaximumPlayerDistance
				and (used[item.Id] or 0) <= now
			then
				local grounded = Spawn.ground(position)
				if grounded then
					return item.Id, grounded
				end
			end
		end
		return nil, nil
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < nextScan then
			return
		end
		nextScan = now + 1
		for index = #entries, 1, -1 do
			local entry = entries[index]
			if
				not entry.Handle.IsAlive()
				or nearest(entry.Handle.Model:GetPivot().Position) > Config.DespawnDistance
			then
				entry.Handle.Destroy()
				table.remove(entries, index)
			end
		end
		if #entries < Config.Cap and now >= nextSpawn then
			nextSpawn = now + Config.SpawnInterval
			local id, position = candidate(now)
			if id and position then
				local handle = Runtime.create(position, folder)
				handle.Model.Name = "AmbientNascent_" .. id
				handle.Model:SetAttribute("Population", "Ambient")
				handle.Model:SetAttribute("SpawnCandidate", id)
				table.insert(entries, { Handle = handle, Candidate = id })
				used[id] = now + Config.MinimumCandidateReuseSeconds
			end
		end
	end)
end

return Ambient
