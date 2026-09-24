--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Configuration.Assignments)
local Locations = require(Shared.Configuration.AssignmentLocations)
local Enemy = require(script.Parent.EnemyService)

local Assignments = {}
type State = {
	Id: string,
	Status: string,
	Location: string,
	Step: number,
	Enemies: { Enemy.Handle },
	Rewarded: boolean,
	Prop: BasePart?,
}
local states: { [Player]: State } = {}

local function prompt(part: BasePart, text: string, action: string, callback: (Player) -> ())
	local p = Instance.new("ProximityPrompt")
	p.ActionText, p.ObjectText, p.HoldDuration, p.MaxActivationDistance = action, text, 0, 10
	p.Parent = part
	p.Triggered:Connect(callback)
	return p
end

local function marker(parent: Instance, name: string, position: Vector3, color: Color3): BasePart
	local part = Instance.new("Part")
	part.Name, part.Size, part.Position = name, Vector3.new(3, 4, 3), position + Vector3.new(0, 2, 0)
	part.Anchored, part.CanCollide, part.Material, part.Color = true, false, Enum.Material.Neon, color
	part.Parent = parent
	return part
end

local function publish(player: Player)
	local state = states[player]
	player:SetAttribute("AssignmentId", state and state.Id or "")
	player:SetAttribute("AssignmentState", state and state.Status or "Available")
	player:SetAttribute("AssignmentLocation", state and state.Location or "Barracks_Main")
	player:SetAttribute("AssignmentStep", state and state.Step or 0)
	player:SetAttribute("AssignmentEnemies", state and #state.Enemies or 0)
end

local function cleanup(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if state.Prop then
		state.Prop:Destroy()
	end
	for _, enemy in state.Enemies do
		enemy.Destroy()
	end
	states[player] = nil
	publish(player)
end

local function choose(definition: any, player: Player): string
	local options = definition.Destinations or definition.Route
	return options[(player.UserId % #options) + 1]
end

local function setReturn(player: Player)
	local state = states[player]
	if not state then
		return
	end
	state.Status = "ReturnRequired"
	if state.Prop then
		state.Prop:Destroy()
		state.Prop = nil
	end
	publish(player)
end

local function spawnEncounter(player: Player, state: State, count: number)
	local center = Locations[state.Location].Position
	for i = 1, count do
		local handle = Enemy.create(
			center + Vector3.new((i - 1) * 7 - 3.5, 4, 8),
			workspace:WaitForChild("RecruitAssignments"):WaitForChild("Encounters"),
			"Default",
			i * 0.03,
			1 / 30
		)
		handle.Model:SetAttribute("AssignmentOwner", player.UserId)
		handle.Model:SetAttribute("AssignmentId", state.Id)
		table.insert(state.Enemies, handle)
	end
end

local function activate(player: Player, state: State)
	local definition = Definitions[state.Id]
	if definition.AssignmentType == "ClearInfestation" then
		state.Status = "Active"
		spawnEncounter(player, state, definition.EnemyCount)
	elseif definition.AssignmentType == "DefendPosition" then
		state.Status = "Active"
		spawnEncounter(player, state, 1)
	else
		state.Step += 1
		if definition.AssignmentType == "Patrol" and state.Step < #definition.Route then
			state.Location = definition.Route[state.Step + 1]
			local loc = Locations[state.Location]
			state.Prop =
				marker(workspace.RecruitAssignments, "AssignmentObjective", loc.Position, Color3.fromRGB(255, 215, 95))
			prompt(state.Prop, loc.Name, "Inspect", function(who)
				if who == player then
					activate(player, state)
				end
			end)
		else
			setReturn(player)
		end
	end
	publish(player)
end

local function accept(player: Player, id: string)
	if states[player] or not Definitions[id] then
		return
	end
	local definition = Definitions[id]
	local location = choose(definition, player)
	local state: State =
		{ Id = id, Status = "Active", Location = location, Step = 0, Enemies = {}, Rewarded = false, Prop = nil }
	states[player] = state
	local loc = Locations[location]
	state.Prop = marker(workspace.RecruitAssignments, "AssignmentObjective", loc.Position, Color3.fromRGB(255, 215, 95))
	prompt(
		state.Prop,
		loc.Name,
		definition.AssignmentType == "DefendPosition" and "Activate" or "Complete",
		function(who)
			if who == player and states[player] == state and state.Status == "Active" then
				activate(player, state)
			end
		end
	)
	publish(player)
end

function Assignments.start()
	local folder = Instance.new("Folder")
	folder.Name = "RecruitAssignments"
	folder.Parent = workspace
	local encounters = Instance.new("Folder")
	encounters.Name = "Encounters"
	encounters.Parent = folder
	local barracks = Locations.Barracks_Main.Position
	local offerIds = { "Patrol", "SupplyDelivery", "Investigation", "ClearInfestation", "DefendPosition" }
	local offerCursor = 1
	local slots: { { Prompt: ProximityPrompt, Id: string } } = {}
	local function refreshOffers()
		for index, slot in slots do
			slot.Id = offerIds[(offerCursor + index - 2) % #offerIds + 1]
			slot.Prompt.ObjectText = Definitions[slot.Id].Name
		end
		offerCursor = offerCursor % #offerIds + 1
	end
	for index = 1, 3 do
		local board = marker(
			folder,
			"AssignmentBoard" .. index,
			barracks + Vector3.new((index - 2) * 5, 0, -8),
			Color3.fromRGB(90, 150, 210)
		)
		local slot = { Prompt = nil :: any, Id = "" }
		slot.Prompt = prompt(board, "Assignment", "Accept", function(player)
			accept(player, slot.Id)
			refreshOffers()
		end)
		table.insert(slots, slot)
	end
	refreshOffers()
	local turnIn = marker(folder, "AssignmentTurnIn", barracks + Vector3.new(0, 0, 7), Color3.fromRGB(110, 220, 130))
	prompt(turnIn, "Assignment Office", "Turn In / Abandon", function(player)
		local state = states[player]
		if state and state.Status == "ReturnRequired" and not state.Rewarded then
			state.Rewarded = true
			player:SetAttribute(
				"MilitaryScrip",
				(player:GetAttribute("MilitaryScrip") or 0) + Definitions[state.Id].Reward
			)
			cleanup(player)
		elseif state then
			cleanup(player)
		end
	end)
	local medical = marker(folder, "BarracksMedical", barracks + Vector3.new(-8, 0, 7), Color3.fromRGB(180, 240, 255))
	prompt(medical, "Barracks Medical", "Recover", function(player)
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if h then
			h.Health = h.MaxHealth
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("MilitaryScrip", 0)
		publish(player)
		player.CharacterAdded:Connect(function(character)
			local h = character:WaitForChild("Humanoid", 10)
			if h then
				h.Died:Connect(function()
					cleanup(player)
				end)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(cleanup)
	for _, player in Players:GetPlayers() do
		player:SetAttribute("MilitaryScrip", 0)
		publish(player)
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for player, state in states do
			for _, enemy in state.Enemies do
				enemy.Update(now)
			end
			for index = #state.Enemies, 1, -1 do
				if not state.Enemies[index].IsAlive() then
					table.remove(state.Enemies, index)
				end
			end
			if
				state.Status == "Active"
				and #state.Enemies == 0
				and (state.Id == "ClearInfestation" or state.Id == "DefendPosition")
			then
				if state.Id == "DefendPosition" and state.Step == 0 then
					state.Step = 1
					spawnEncounter(player, state, 1)
				else
					setReturn(player)
				end
			end
			publish(player)
		end
	end)
end

return Assignments
