--!strict
-- Defend the Walls: hold three walls and the final doors through a timed, phased
-- assault. Round flow, participants, rewards and analytics come from ModeRunner;
-- the map comes from DefendTheWallsMap and the NPC guards from DefendTheWallsGuards.
-- This file owns wall progression (each wall's shared integrity, breaches, fallback
-- spawn), the doors (the only loss condition) and repairs, the phase table and spawning.
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Configuration.DefendTheWalls)
local Runtime = require(script.Parent.EnemyRuntime)
local Damage = require(script.Parent.DamageService)
local ModeRunner = require(script.Parent.ModeRunner)
local Map = require(script.Parent.DefendTheWallsMap)
local Guards = require(script.Parent.DefendTheWallsGuards)
local Mission = {}

local runner: ModeRunner.Runner
local entries: { any } = {}
local built: Map.Built
local gateway: Model -- the final doors
local gateHealth: Humanoid
local repairPrompts: { ProximityPrompt } = {} -- [1..3] walls, [4] doors
local folder: Folder
local enemies: Folder
local squad: Guards.Squad
local phase = 1
local nextSpawn = 0
local repairs = Config.RepairCharges
local spawned = 0
local budgetRemaining = 0
local defeated = 0
local stuckRemoved = 0
local eliteSpawned = false
-- Wall progression: 1-3 are the walls, Config.Walls.Count + 1 means only the doors remain.
local wallLevel = 1
local wallHP = 0
local gateOwner: { [Humanoid]: number } = {} -- gate proxy Humanoid -> wall level
local DOORS = Config.Walls.Count + 1

local function prompt(parent: BasePart, action: string, object: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText = action, object
	p.HoldDuration, p.MaxActivationDistance = 2, Config.RepairDistance
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function build(runner: ModeRunner.Runner): Folder
	built = Map.build()
	folder = built.Folder
	gateway = built.Doors
	gateHealth = gateway:FindFirstChildOfClass("Humanoid") :: Humanoid
	for level, handles in built.Levels do
		repairPrompts[level] = prompt(handles.Console, "Repair wall " .. level, "Defense console")
	end
	repairPrompts[DOORS] = prompt(built.DoorConsole, "Repair gateway", "Gate console")
	enemies = Instance.new("Folder")
	enemies.Name, enemies.Parent = "MissionEnemies", folder
	squad = Guards.new(folder, built.Levels, function()
		local models = {}
		for _, entry in entries do
			if entry.Handle.IsAlive() and entry.Handle.Model.Parent then
				table.insert(models, entry.Handle.Model)
			end
		end
		return models
	end)
	local hubSpawn = Instance.new("SpawnLocation")
	hubSpawn.Name, hubSpawn.Size, hubSpawn.Position =
		"MissionHubSpawn", Vector3.new(8, 1, 8), Config.Hub - Vector3.new(0, 5, 0)
	hubSpawn.Anchored, hubSpawn.Neutral, hubSpawn.Duration = true, true, 0
	hubSpawn.Parent = folder
	local sandboxGate = Instance.new("Part")
	sandboxGate.Name, sandboxGate.Size, sandboxGate.Anchored = "SandboxAccess", Vector3.new(5, 7, 3), true
	sandboxGate.Position = Config.Hub + Vector3.new(-24, -2.5, 4)
	sandboxGate.Material, sandboxGate.Color = Enum.Material.Slate, Color3.fromRGB(148, 115, 74)
	sandboxGate.Parent = folder
	local sandboxPrompt = Instance.new("ProximityPrompt")
	sandboxPrompt.ActionText, sandboxPrompt.ObjectText = "Enter combat sandbox", "Practice gate"
	sandboxPrompt.MaxActivationDistance, sandboxPrompt.HoldDuration = 10, 0.5
	sandboxPrompt.Parent = sandboxGate
	sandboxPrompt.Triggered:Connect(function(player)
		if runner.Participants[player] then
			return
		end
		player:SetAttribute("MissionSandbox", true)
		player:LoadCharacter()
	end)
	return folder
end

local function freshHumanoid(model: Model, maximum: number): Humanoid
	local old = model:FindFirstChildOfClass("Humanoid")
	if old then
		gateOwner[old] = nil
		old:Destroy()
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth, humanoid.Health = maximum, maximum
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	return humanoid
end

-- Rebuilds every gate proxy and the doors at full integrity, gates closed.
local function resetDefenses()
	for level, handles in built.Levels do
		Map.Walls.setBreached(handles, false)
		for _, gate in handles.Gates do
			gateOwner[freshHumanoid(gate, Config.Walls.Integrity[level])] = level
			gate:SetAttribute("MissionId", nil)
			CollectionService:RemoveTag(gate, "CityHuman")
		end
	end
	gateHealth = freshHumanoid(gateway, Config.GatewayIntegrity)
end

local function syncWall()
	local handles = built.Levels[wallLevel]
	if not handles then
		return
	end
	for _, gate in handles.Gates do
		local humanoid = gate:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = math.max(0, wallHP)
		end
	end
end

-- Current objective for an enemy that chose `lane`: its gate on the active wall, else the doors.
local function objectiveFor(lane: number): Model
	local handles = built.Levels[wallLevel]
	return if handles then handles.Gates[lane] or gateway else gateway
end

local function setWall(level: number)
	wallLevel = level
	local handles = built.Levels[level]
	for index, p in repairPrompts do
		p.Enabled = index == level
	end
	if handles then
		wallHP = Config.Walls.Integrity[level]
		for _, gate in handles.Gates do
			gate:SetAttribute("MissionId", runner.RoundId)
			-- Enemy swings only land on players and CityHuman-tagged targets.
			CollectionService:AddTag(gate, "CityHuman")
		end
	else
		wallHP = 0
	end
	folder:SetAttribute("WallLevel", level)
	folder:SetAttribute("DefenderSpawn", if handles then handles.Fallback else Config.Hub)
	for _, entry in entries do
		entry.Order.Value = objectiveFor(entry.Lane)
	end
end

local function breachWall()
	local fallen = built.Levels[wallLevel]
	if not fallen then
		return
	end
	Map.Walls.setBreached(fallen, true)
	for _, gate in fallen.Gates do
		gate:SetAttribute("MissionId", nil)
		CollectionService:RemoveTag(gate, "CityHuman")
		local humanoid = gate:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Health = 0 -- enemies drop it as a target and take the new objective
		end
	end
	runner.metric("WallsBreached")
	local from = wallLevel
	setWall(wallLevel + 1)
	squad.retreat(from, wallLevel)
	runner.snapshot(nil)
end

local function activeCount(): number
	local n = 0
	for _, entry in entries do
		if entry.Handle.IsAlive() and entry.Handle.Model.Parent then
			n += 1
		end
	end
	return n
end

local function cleanupEnemies()
	for _, entry in entries do
		entry.Connection:Disconnect()
		entry.Handle.Destroy()
	end
	table.clear(entries)
end

local function spawnEnemy(kind: string)
	local definition = Config.Phases[phase]
	local lane = definition.Lanes[math.random(1, #definition.Lanes)]
	local position = built.Spawns[lane] + Vector3.new(math.random(-8, 8), 0, math.random(-4, 4))
	-- Some enemies branch at the crossroads and hit another lane's gate.
	local goal = lane
	if math.random() < Config.Map.BranchChance then
		goal = (lane + math.random(0, 1)) % Config.Walls.Count + 1
	end
	local handle = Runtime.create(position, enemies, kind)
	local model = handle.Model
	model:SetAttribute("MissionId", runner.RoundId)
	model:SetAttribute("MissionRole", kind)
	model:SetAttribute("SandboxLabel", kind .. " Enfleshed")
	local order = Instance.new("ObjectValue")
	order.Name, order.Value, order.Parent = "ObjectiveTarget", objectiveFor(goal), model
	model:SetAttribute("MissionLane", goal)
	local health = model:FindFirstChildOfClass("Humanoid")
	if health then
		local hp = if kind == "Swift" then 115 elseif kind == "Brute" then 260 elseif kind == "Elite" then 440 else 160
		health.MaxHealth, health.Health = hp, hp
		health.WalkSpeed = if kind == "Swift" then 22 elseif kind == "Brute" or kind == "Elite" then 13 else 18
	end
	if kind == "Brute" or kind == "Elite" then
		model:ScaleTo(if kind == "Elite" then 1.5 else 1.25)
		local highlight = Instance.new("Highlight")
		highlight.FillColor = if kind == "Elite" then Color3.fromRGB(212, 62, 57) else Color3.fromRGB(135, 100, 62)
		highlight.FillTransparency = 0.7
		highlight.Parent = model
	end
	local connection = (health :: Humanoid).Died:Connect(function()
		if runner.State == "ACTIVE" and model:GetAttribute("MissionId") == runner.RoundId then
			defeated += 1
			runner.metric("EnemiesDefeated")
		end
	end)
	table.insert(entries, {
		Handle = handle,
		Connection = connection,
		Order = order,
		Lane = goal,
		Last = position,
		ProgressAt = os.clock(),
		Born = os.clock(),
	})
	spawned += 1
	budgetRemaining -= 1
end

local function updateEnemies(now: number)
	local elapsed = (now - runner.StartAt) * Config.Duration / runner.Duration
	for index = #Config.Phases, 1, -1 do
		if elapsed >= Config.Phases[index].At then
			if index ~= phase then
				phase = index
				budgetRemaining = Config.Phases[index].Budget
				runner.snapshot(nil)
			end
			break
		end
	end
	for index = #entries, 1, -1 do
		local entry = entries[index]
		local model = entry.Handle.Model
		if not model.Parent or not entry.Handle.IsAlive() then
			entry.Connection:Disconnect()
			if model.Parent then
				entry.Handle.Destroy()
			end
			table.remove(entries, index)
		else
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				if (root.Position - entry.Last).Magnitude > 5 then
					entry.Last, entry.ProgressAt = root.Position, os.clock()
				end
				local objective = entry.Order.Value
				local goal = if objective and objective:IsA("Model")
					then objective:GetPivot().Position
					else Config.Gateway
				if os.clock() - entry.ProgressAt > Config.StuckTimeout and (root.Position - goal).Magnitude > 13 then
					entry.Connection:Disconnect()
					entry.Handle.Destroy()
					table.remove(entries, index)
					stuckRemoved += 1
				end
			end
		end
	end
	local party = math.max(1, runner.countParticipants())
	local definition = Config.Phases[phase]
	local cap = definition.Cap + (party - 1) * 4
	if phase >= 4 and not eliteSpawned and budgetRemaining > 0 and activeCount() < cap then
		eliteSpawned = true
		spawnEnemy("Elite")
	end
	if now >= nextSpawn and budgetRemaining > 0 and activeCount() < cap then
		local kind = "Basic"
		local roll = math.random()
		if phase >= 3 and roll < 0.15 then
			kind = "Brute"
		elseif phase >= 2 and roll < 0.4 then
			kind = "Swift"
		end
		spawnEnemy(kind)
		nextSpawn = now
			+ (
				if activeCount() < definition.Target + (party - 1) * 3
					then 2
					else definition.Interval / (1 + (party - 1) * 0.2)
			)
	end
end

local function rewardFor(_runner: ModeRunner.Runner, data: ModeRunner.Participant, victory: boolean): ModeRunner.Reward
	local participation =
		math.clamp((workspace:GetServerTimeNow() - data.Joined) / math.max(1, runner.Duration * 0.5), 0, 1)
	local bonus = math.clamp(math.floor(data.Damage / 500) + data.Repairs * 3 + data.Kills, 0, 10)
	local baseXP = if victory then Config.Rewards.VictoryXP else Config.Rewards.DefeatXP
	local baseMarks = if victory then Config.Rewards.VictoryMarks else Config.Rewards.DefeatMarks
	return {
		XP = math.floor((baseXP + bonus * 2) * participation),
		Marks = math.floor((baseMarks + bonus) * participation),
		Kills = data.Kills,
		Repairs = data.Repairs,
		Score = math.floor(data.Damage + data.Kills * 25 + data.Repairs * 100),
		Victory = victory,
		Deaths = data.Deaths,
	}
end

local function definition(remote: RemoteEvent): ModeRunner.ModeDefinition
	return {
		Id = "DefendTheWalls",
		Tier = 1,
		Remote = remote,
		Preparation = Config.Preparation,
		Results = Config.Results,
		MaxParticipants = Config.MaxParticipants,
		ParticipantAttribute = "MissionDefender",
		UnavailableText = "Defend the Walls is temporarily unavailable",
		build = build,
		duration = function()
			return if RunService:IsStudio() and Config.Studio.Accelerated
				then Config.Studio.Duration
				else Config.Duration
		end,
		timeoutOutcome = true, -- the gate held until the timer ran out
		prepare = function(current)
			resetDefenses()
			gateway:SetAttribute("MissionId", current.RoundId)
			setWall(1)
			squad.spawn(current.RoundId)
			phase, repairs, spawned, defeated, stuckRemoved = 1, Config.RepairCharges, 0, 0, 0
			budgetRemaining = Config.Phases[1].Budget
			eliteSpawned = false
		end,
		activate = function()
			nextSpawn = 0
		end,
		outcome = function()
			return if gateHealth.Health <= 0 then false else nil
		end,
		tick = function(_, now)
			updateEnemies(now)
		end,
		cleanup = function()
			cleanupEnemies()
			squad.clear()
			resetDefenses()
			setWall(1)
			repairs = Config.RepairCharges
		end,
		reward = rewardFor,
		newParticipant = function()
			return { Repairs = 0 }
		end,
		snapshot = function(_, message)
			message.Phase = phase
			message.PhaseName = Config.Phases[phase].Name
			message.Gateway = gateHealth.Health
			message.GatewayMax = gateHealth.MaxHealth
			message.WallLevel = wallLevel
			message.WallCount = Config.Walls.Count
			message.WallHP = math.max(0, wallHP)
			message.WallMax = if built.Levels[wallLevel] then Config.Walls.Integrity[wallLevel] else 0
			message.GuardsAlive = squad.alive()
			message.GuardsTotal = squad.total()
			message.Repairs = repairs
			message.Enemies = activeCount()
			message.Spawned = spawned
			message.Defeated = defeated
			message.StuckRemoved = stuckRemoved
			message.SpawnBudget = budgetRemaining
		end,
		progressLabel = function()
			return phase
		end,
	}
end

function Mission.start()
	local remotes = Shared:WaitForChild("SandboxRemotes")
	runner = ModeRunner.new(definition(remotes:WaitForChild("MissionRemote") :: RemoteEvent))
	runner.start()
	local function repair(player: Player, index: number)
		local data = runner.Participants[player]
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local health = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local console = repairPrompts[index].Parent :: BasePart
		if
			runner.State ~= "ACTIVE"
			or index ~= wallLevel -- only the active wall (or the doors) can be repaired
			or not data
			or repairs <= 0
			or not root
			or not root:IsA("BasePart")
			or not health
			or health.Health <= 0
			or (root.Position - console.Position).Magnitude > Config.RepairDistance + 2
		then
			return
		end
		if index == DOORS then
			if gateHealth.Health >= gateHealth.MaxHealth then
				return
			end
			gateHealth.Health = math.min(gateHealth.MaxHealth, gateHealth.Health + Config.RepairAmount)
		else
			local maximum = Config.Walls.Integrity[index]
			if wallHP >= maximum then
				return
			end
			wallHP = math.min(maximum, wallHP + Config.RepairAmount)
			syncWall()
		end
		repairs -= 1
		runner.metric("RepairsUsed")
		data.Repairs += 1
		runner.snapshot(nil)
	end
	for index, p in repairPrompts do
		p.Triggered:Connect(function(player)
			repair(player, index)
		end)
	end
	Damage.Applied:Connect(function(_attacker: Model, target: Humanoid, amount: number, killed: boolean)
		if runner.State ~= "ACTIVE" then
			return
		end
		if target == gateHealth then
			runner.snapshot(nil)
			if killed then
				runner.finish(false) -- only the final doors lose the mission
			end
		elseif gateOwner[target] == wallLevel then
			wallHP -= amount
			syncWall()
			if wallHP <= 0 then
				breachWall()
			else
				runner.snapshot(nil)
			end
		end
	end)
	-- The practice sandbox is reached from this mode's hub.
	local function resetSandbox(player: Player)
		player:SetAttribute("MissionSandbox", false)
	end
	Players.PlayerAdded:Connect(resetSandbox)
	for _, player in Players:GetPlayers() do
		resetSandbox(player)
	end
end

function Mission.debugFinish(victory: boolean)
	if not RunService:IsStudio() or not Config.Studio.Accelerated or not Config.Studio.MockProgression then
		return
	end
	runner.finish(victory)
end

function Mission.debugDamage(amount: number)
	if not RunService:IsStudio() or not Config.Studio.Accelerated or not Config.Studio.MockProgression then
		return
	end
	if runner.State == "ACTIVE" and type(amount) == "number" and amount == amount then
		gateHealth.Health = math.max(0, gateHealth.Health - math.clamp(amount, 0, Config.GatewayIntegrity))
		if gateHealth.Health <= 0 then
			runner.finish(false)
		else
			runner.snapshot(nil)
		end
	end
end

-- Studio-only load test: spawns `count` enemies across all three lanes right now,
-- ignoring phase caps, so the perf script can measure a full three-lane wave.
function Mission.debugWave(count: number)
	if not RunService:IsStudio() or runner.State ~= "ACTIVE" or type(count) ~= "number" then
		return
	end
	local saved = phase
	phase = #Config.Phases -- every lane open
	for i = 1, math.clamp(math.floor(count), 0, 60) do
		spawnEnemy(if i % 9 == 0 then "Brute" elseif i % 3 == 0 then "Swift" else "Basic")
	end
	phase = saved
	runner.snapshot(nil)
end

-- Breaks the active wall at once, to test fallbacks and guard retreats.
function Mission.debugBreach()
	if not RunService:IsStudio() or not Config.Studio.Accelerated or not Config.Studio.MockProgression then
		return
	end
	if runner.State == "ACTIVE" and built.Levels[wallLevel] then
		wallHP = 0
		breachWall()
	end
end

return Mission
