--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Configuration.Sandbox).TrainingDummies
local DevelopmentSandbox = require(Shared.Configuration.DevelopmentSandbox)

type DummyEntry = {
	Alignment: string,
	Model: Model?,
	Position: Vector3,
	Generation: number,
}

local TrainingDummies = {}
local entries: { [Player]: { DummyEntry } } = {}
local lastRequest: { [Player]: number } = {}
local folder: Folder?

local function countAll(): number
	local count = 0
	for _, owned in entries do
		count += #owned
	end
	return count
end

local function countOwned(player: Player): number
	return #(entries[player] or {})
end

local function updateHealthLabel(model: Model, humanoid: Humanoid, alignment: string)
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("TrainingDummyNameplate")
	local label = gui and gui:FindFirstChild("Label")
	local bar = gui and gui:FindFirstChild("Bar")
	local fill = bar and bar:FindFirstChild("Fill")
	if label and label:IsA("TextLabel") then
		label.Text =
			string.format("%s TRAINING · %d / %d", alignment:upper(), math.ceil(humanoid.Health), humanoid.MaxHealth)
	end
	if fill and fill:IsA("Frame") then
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / math.max(1, humanoid.MaxHealth), 0, 1), 1)
	end
end

local function makePart(
	model: Model,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material
)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = root.CFrame * CFrame.new(offset)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = material
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function makeNameplate(head: BasePart, alignment: string)
	local gui = Instance.new("BillboardGui")
	gui.Name = "TrainingDummyNameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffset = Vector3.new(0, 1.15, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, 27)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = if alignment == "Ally" then Color3.fromRGB(141, 230, 177) else Color3.fromRGB(255, 145, 125)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Position = UDim2.fromOffset(32, 28)
	bar.Size = UDim2.new(1, -64, 0, 7)
	bar.BackgroundColor3 = Color3.fromRGB(34, 30, 31)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if alignment == "Ally" then Color3.fromRGB(77, 203, 128) else Color3.fromRGB(223, 79, 69)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	return gui
end

local function createModel(entry: DummyEntry, owner: Player)
	local alignment = entry.Alignment
	local tone = if alignment == "Ally" then Color3.fromRGB(91, 126, 113) else Color3.fromRGB(126, 77, 73)
	local trim = if alignment == "Ally" then Color3.fromRGB(180, 165, 125) else Color3.fromRGB(171, 92, 75)
	local model = Instance.new("Model")
	model.Name = alignment .. "TrainingDummy"
	model:SetAttribute("SandboxTrainingDummy", true)
	model:SetAttribute("SandboxAlignment", alignment)
	model:SetAttribute("SandboxOwnerUserId", owner.UserId)
	model:SetAttribute("SandboxLabel", alignment .. " Training Dummy")
	if alignment == "Enemy" then
		CollectionService:AddTag(model, "MagicHostileTarget")
	else
		CollectionService:AddTag(model, "MagicAllyTarget")
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	local ownerRoot = owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
	local center = entry.Position + Vector3.new(0, 2.75, 0)
	local facing = if ownerRoot and ownerRoot:IsA("BasePart")
		then Vector3.new(ownerRoot.Position.X, center.Y, ownerRoot.Position.Z)
		else center + Vector3.zAxis
	root.CFrame = CFrame.lookAt(center, facing)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.Parent = model
	model.PrimaryPart = root

	makePart(model, "Torso", Vector3.new(2.1, 2.1, 1.15), Vector3.new(0, 0.05, 0), tone, Enum.Material.SmoothPlastic)
	makePart(
		model,
		"Head",
		Vector3.new(1.2, 1.2, 1.2),
		Vector3.new(0, 1.75, 0),
		Color3.fromRGB(177, 153, 128),
		Enum.Material.SmoothPlastic
	)
	makePart(model, "Left Arm", Vector3.new(0.7, 2, 0.8), Vector3.new(-1.35, 0, 0), tone, Enum.Material.SmoothPlastic)
	makePart(model, "Right Arm", Vector3.new(0.7, 2, 0.8), Vector3.new(1.35, 0, 0), tone, Enum.Material.SmoothPlastic)
	makePart(
		model,
		"Left Leg",
		Vector3.new(0.85, 1.8, 0.95),
		Vector3.new(-0.52, -1.95, 0),
		trim,
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"Right Leg",
		Vector3.new(0.85, 1.8, 0.95),
		Vector3.new(0.52, -1.95, 0),
		trim,
		Enum.Material.WoodPlanks
	)

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.MaxHealth = Config.Health
	humanoid.Health = humanoid.MaxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	local head = model:FindFirstChild("Head") :: BasePart
	makeNameplate(head, alignment)
	humanoid.HealthChanged:Connect(function()
		updateHealthLabel(model, humanoid, alignment)
	end)
	updateHealthLabel(model, humanoid, alignment)
	model.Parent = folder
	entry.Model = model
	entry.Generation += 1
	local generation = entry.Generation
	humanoid.Died:Once(function()
		task.delay(Config.ResetDelay, function()
			if
				entry.Generation == generation
				and entry.Model == model
				and model.Parent
				and table.find(entries[owner] or {}, entry)
			then
				model:Destroy()
				entry.Model = nil
				createModel(entry, owner)
			end
		end)
	end)
end

local function removeEntry(player: Player, entry: DummyEntry)
	local owned = entries[player]
	if not owned then
		return
	end
	local index = table.find(owned, entry)
	if not index then
		return
	end
	table.remove(owned, index)
	entry.Generation += 1
	if entry.Model then
		entry.Model:Destroy()
		entry.Model = nil
	end
	if #owned == 0 then
		entries[player] = nil
	end
end

local function getSpawnPosition(player: Player, root: BasePart): Vector3?
	local dummyFolder = folder
	if not dummyFolder then
		return nil
	end
	local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if forward.Magnitude < 0.1 then
		forward = Vector3.zAxis
	end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, dummyFolder }
	params.IgnoreWater = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { player.Character, dummyFolder }
	for attempt = 1, Config.SpawnAttempts do
		local ring = math.ceil(attempt / 4)
		local side = ((attempt - 1) % 4) - 1.5
		local desired = root.Position + forward * (Config.SpawnDistance + (ring - 1) * 3) + right * (side * 2.5)
		local origin = desired + Vector3.new(0, 12, 0)
		local hit = workspace:Raycast(origin, Vector3.new(0, -42, 0), params)
		if hit and hit.Normal.Y > 0.6 then
			local position = hit.Position + Vector3.new(0, 0.08, 0)
			local blocked = false
			for _, part in
				workspace:GetPartBoundsInBox(
					CFrame.new(position + Vector3.new(0, 2.8, 0)),
					Vector3.new(3.2, 5.2, 2.2),
					overlap
				)
			do
				if part.CanCollide then
					blocked = true
					break
				end
			end
			if not blocked then
				return position
			end
		end
	end
	return nil
end

local function respond(remote: RemoteEvent, player: Player, ok: boolean, text: string)
	remote:FireClient(player, ok, text, countOwned(player), Config.MaxPerPlayer)
end

function TrainingDummies.start(remoteFolder: Folder, getState: (Player) -> any)
	if not Config.Enabled or not RunService:IsStudio() then
		return
	end
	local rootFolder = Instance.new("Folder")
	rootFolder.Name = "TrainingDummies"
	rootFolder.Parent = workspace
	folder = rootFolder
	local function remote(name: string): RemoteEvent
		local existing = remoteFolder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local event = Instance.new("RemoteEvent")
		event.Name, event.Parent = name, remoteFolder
		return event
	end
	local request = remote("TrainingDummyRequest")
	local response = remote("TrainingDummyResponse")

	request.OnServerEvent:Connect(function(player: Player, action: any)
		local studioSandbox = RunService:IsStudio() and DevelopmentSandbox.Enabled == true
		if typeof(action) ~= "string" or (not studioSandbox and not player:GetAttribute("CharacterReady")) then
			return
		end
		local now = os.clock()
		if now - (lastRequest[player] or -math.huge) < Config.RequestCooldown then
			respond(response, player, false, "Please wait before sending another training command.")
			return
		end
		lastRequest[player] = now
		local state = getState(player)
		if not state or state.Character ~= player.Character or state.Humanoid.Health <= 0 then
			respond(response, player, false, "Your character is not ready.")
			return
		end
		if action == "SpawnAlly" or action == "SpawnEnemy" then
			if countOwned(player) >= Config.MaxPerPlayer or countAll() >= Config.MaxTotal then
				respond(response, player, false, "Training dummy limit reached. Clear some dummies first.")
				return
			end
			local position = getSpawnPosition(player, state.Root)
			if not position then
				respond(response, player, false, "No clear ground nearby. Move to an open floor and try again.")
				return
			end
			local alignment = if action == "SpawnAlly" then "Ally" else "Enemy"
			local entry: DummyEntry = { Alignment = alignment, Model = nil, Position = position, Generation = 0 }
			entries[player] = entries[player] or {}
			table.insert(entries[player], entry)
			createModel(entry, player)
			respond(response, player, true, alignment .. " training dummy spawned.")
		elseif action == "ResetMine" then
			for _, entry in entries[player] or {} do
				local model = entry.Model
				local humanoid = model and model:FindFirstChildOfClass("Humanoid")
				if not model or not humanoid or humanoid.Health <= 0 then
					if model then
						model:Destroy()
						entry.Model = nil
					end
					createModel(entry, player)
				else
					humanoid.Health = humanoid.MaxHealth
				end
			end
			respond(response, player, true, "Your training dummies have been reset.")
		elseif action == "ClearMine" then
			for _, entry in table.clone(entries[player] or {}) do
				removeEntry(player, entry)
			end
			respond(response, player, true, "Your training dummies have been cleared.")
		elseif action == "RestorePlayer" then
			local restored = require(script.Parent.MagicService).restoreTestingResources(player)
			if restored then
				state.Humanoid.Health = state.Humanoid.MaxHealth
			end
			respond(
				response,
				player,
				restored,
				if restored
					then "Health and magic resources restored."
					else "Magic resources are still loading; try again."
			)
		elseif action == "ClearEffects" then
			require(script.Parent.MagicService).reset(player)
			respond(response, player, true, "Your active spells and cooldowns have been reset.")
		elseif action == "ResetPlayer" then
			player:LoadCharacter()
		elseif action == "ReturnToStart" and require(script.Parent.CombatSandboxService).enabled() then
			local position = require(Shared.Configuration.CombatBattleMap).Spawn
			state.Character:PivotTo(CFrame.new(position))
			state.Root.AssemblyLinearVelocity = Vector3.zero
			state.LastPosition, state.LastFramePosition = position, position
			state.SpawnGraceUntil = workspace:GetServerTimeNow() + 2
			respond(response, player, true, "Returned to the practice start.")
		else
			respond(response, player, false, "Unknown training command.")
		end
	end)

	if require(script.Parent.CombatSandboxService).enabled() then
		local function bindPractice(player)
			local function seed()
				if not player:GetAttribute("CharacterReady") or countOwned(player) > 0 then
					return
				end
				local state = getState(player)
				if not state then
					return
				end
				for i, alignment in { "Enemy", "Ally" } do
					if countAll() >= Config.MaxTotal or countOwned(player) >= Config.MaxPerPlayer then
						break
					end
					local position = getSpawnPosition(player, state.Root)
					if position then
						position += Vector3.new((i - 1) * 7, 0, 0)
						local entry = { Alignment = alignment, Model = nil, Position = position, Generation = 0 }
						entries[player] = entries[player] or {}
						table.insert(entries[player], entry)
						createModel(entry, player)
					end
				end
			end
			player:GetAttributeChangedSignal("CharacterReady"):Connect(seed)
			seed()
		end
		Players.PlayerAdded:Connect(bindPractice)
		for _, player in Players:GetPlayers() do
			bindPractice(player)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, entry in table.clone(entries[player] or {}) do
			removeEntry(player, entry)
		end
		lastRequest[player] = nil
	end)
end

return TrainingDummies
