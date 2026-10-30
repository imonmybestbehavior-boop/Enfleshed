--!strict

-- Server-authoritative inventory: persistence, validated client requests,
-- consumable use and world loot drops. Equipment reads equipped instances from here.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Protocol = require(Shared.Networking.Protocol)
local Loot = require(Shared.Configuration.Loot)
local StudioSandbox = require(Shared.Configuration.DevelopmentSandbox)
local Rules = require(Shared.Modules.ItemRules)
local Model = require(Shared.Modules.InventoryModel)
local Damage = require(script.Parent.DamageService)

local Inventory = {}
local changed = Instance.new("BindableEvent")
Inventory.Changed = changed.Event -- (player)

local Profiles = require(script.Parent.PlayerProfileService)
local FeatureFlags = require(script.Parent.FeatureFlagService)

type Record = {
	Inventory: Model.Inventory,
	Session: any?, -- Session-locked player profile; nil until loaded or when it could not be read.
	Ready: boolean, -- Load attempt finished and the inventory is usable.
	NextUseAt: number,
	RequestTokens: number,
	RequestUpdated: number,
}

local records: { [Player]: Record } = {}
local remote: RemoteEvent? = nil
local rng = Random.new()
local lootFolder: Folder? = nil

local function uid(): string
	return HttpService:GenerateGUID(false)
end

local function publish(player: Player)
	local record = records[player]
	if not record then
		return
	end
	-- Keep the profile copy current; the profile service persists it.
	if record.Session and record.Session.Writable then
		record.Session.Data.Inventory = { Version = 1, Items = Model.serialize(record.Inventory) }
	end
	if not remote then
		return
	end
	remote:FireClient(player, { Kind = "Snapshot", Items = Model.serialize(record.Inventory) })
	changed:Fire(player)
end

local function notify(player: Player, text: string)
	if remote then
		remote:FireClient(player, { Kind = "Notice", Text = text })
	end
end

local function grantInstance(record: Record, itemId: string, rarityBonus: number?, count: number?): number
	local instance = Rules.roll(itemId, rng, uid(), rarityBonus, count)
	return if instance then Model.add(record.Inventory, instance) else 0
end

-- Starter kit for empty profiles. Studio sandbox additionally receives one of
-- every melee archetype so all weapons can be tried immediately.
local function grantStarter(record: Record)
	local inventory = record.Inventory
	inventory.Equip.MainHand = Rules.new("RecruitMeleeWeapon", uid())
	inventory.Equip.MagicFocus = Rules.new("RecruitMagicWeapon", uid())
	inventory.Quick[1] = Rules.new("FieldDressing", uid(), 3)
	if RunService:IsStudio() and StudioSandbox.Enabled then
		for _, itemId in
			{
				"WallwardLongsword",
				"NotchedFalchion",
				"BreachersGreatsword",
				"ThornKnife",
				"LinePike",
				"PaddedGambeson",
			}
		do
			grantInstance(record, itemId, 2)
		end
	end
end

function Inventory.bind(player: Player)
	local record: Record = {
		Inventory = Model.blank(),
		Session = nil,
		Ready = false,
		NextUseAt = 0,
		RequestTokens = 10,
		RequestUpdated = os.clock(),
	}
	records[player] = record
	local session = Profiles.get(player.UserId)
	if records[player] ~= record then
		return
	end
	if not session or not session.Writable then
		warn("[Inventory] could not load " .. player.Name .. "; using a temporary inventory that will not save")
	end
	local saved = if session then session.Data.Inventory else nil
	record.Inventory = Model.deserialize(if type(saved) == "table" then saved.Items else nil)
	record.Session = session
	if Model.isEmpty(record.Inventory) then
		grantStarter(record)
	end
	record.Ready = true
	publish(player)
end

function Inventory.remove(player: Player)
	-- publish() already mirrored every change into the profile, which saves on leave.
	records[player] = nil
end

function Inventory.ready(player: Player): boolean
	local record = records[player]
	return record ~= nil and record.Ready
end

function Inventory.equipped(player: Player, slot: string): Rules.Instance?
	local record = records[player]
	return if record then record.Inventory.Equip[slot] else nil
end

function Inventory.armor(player: Player): number
	local record = records[player]
	if not record then
		return 0
	end
	local equip = record.Inventory.Equip
	return Rules.armor({ equip.Head, equip.Body, equip.Legs })
end

-- Grants a rolled item; returns false when it did not fully fit.
function Inventory.grant(player: Player, itemId: string, rarityBonus: number?, count: number?): boolean
	local record = records[player]
	if not record or not record.Ready then
		return false
	end
	local leftover = grantInstance(record, itemId, rarityBonus, count)
	publish(player)
	return leftover == 0
end

local function dropInWorld(instance: Rules.Instance, position: Vector3, ownerUserId: number?)
	local definition = Rules.definition(instance.ItemId)
	if not definition or not lootFolder then
		return
	end
	local rarity = Rules.rarity(instance.Rarity)
	local part = Instance.new("Part")
	part.Name = "Loot_" .. instance.ItemId
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = rarity.Color
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { lootFolder }
	for _, model in CollectionService:GetTagged("Enfleshed") do
		table.insert(ignore, model)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(ignore, other.Character)
		end
	end
	ray.FilterDescendantsInstances = ignore
	ray.RespectCanCollide = true
	local scatter = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	local hit = workspace:Raycast(position + scatter + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), ray)
	part.Position = (if hit then hit.Position else position + scatter) + Vector3.new(0, 1, 0)
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = part
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(180, 24)
	label.StudsOffset = Vector3.new(0, 1.6, 0)
	label.MaxDistance = 60
	label.AlwaysOnTop = true
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextScaled = true
	text.TextColor3 = rarity.Color
	text.TextStrokeTransparency = 0.3
	local name = Rules.displayName(instance)
	text.Text = if instance.Count > 1 then string.format("%s ×%d", name, instance.Count) else name
	text.Parent = label
	label.Parent = part
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.T
	prompt.Parent = part
	local droppedAt = os.clock()
	prompt.Triggered:Connect(function(player)
		local record = records[player]
		if not record or not record.Ready or not part.Parent then
			return
		end
		if ownerUserId and player.UserId ~= ownerUserId and os.clock() - droppedAt < Loot.PickupOwnerSeconds then
			notify(player, "That drop belongs to another defender for now")
			return
		end
		local before = instance.Count
		local leftover = Model.add(record.Inventory, instance)
		if leftover == before then
			notify(player, "Inventory full")
			return
		end
		if leftover > 0 then
			instance.Count = leftover
			text.Text = string.format("%s ×%d", name, leftover)
		else
			part:Destroy()
		end
		publish(player)
	end)
	part.Parent = lootFolder
	task.delay(Loot.PickupLifetime, function()
		if part.Parent then
			part:Destroy()
		end
	end)
end

function Inventory.dropLoot(role: string, position: Vector3, ownerUserId: number?)
	if not FeatureFlags.enabled("LootDrops") then
		return
	end
	for _, drop in Rules.rollDrops(role, rng) do
		local instance = Rules.roll(drop.ItemId, rng, uid(), drop.RarityBonus, drop.Count)
		if instance then
			dropInWorld(instance, position, ownerUserId)
		end
	end
end

local function heal(player: Player, record: Record, location: Model.Location): boolean
	local instance = Model.get(record.Inventory, location)
	local definition = if instance then Rules.definition(instance.ItemId) else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not definition or definition.Category ~= "Consumable" or not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = os.clock()
	if now < record.NextUseAt then
		return false
	end
	if definition.Heal then
		if humanoid.Health >= humanoid.MaxHealth then
			notify(player, "Already at full health")
			return false
		end
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + definition.Heal)
	end
	record.NextUseAt = now + (definition.UseCooldown or 1)
	Model.take(record.Inventory, location, 1, uid())
	return true
end

local function handle(player: Player, message: any)
	local record = records[player]
	if not record or not record.Ready or type(message) ~= "table" then
		return
	end
	local clock = os.clock()
	record.RequestTokens = math.min(10, record.RequestTokens + (clock - record.RequestUpdated) * 8)
	record.RequestUpdated = clock
	if record.RequestTokens < 1 then
		return
	end
	record.RequestTokens -= 1
	local op = message.Op
	local ok, reason = false, nil
	if op == "Refresh" then
		ok = true
	elseif op == "Move" then
		ok, reason = Model.move(record.Inventory, message.From, message.To)
	elseif op == "Split" then
		ok, reason = Model.split(record.Inventory, message.From, message.Amount, uid())
	elseif op == "Use" then
		local location = Model.parse(message.From)
		ok = location ~= nil and heal(player, record, location)
	elseif op == "Drop" then
		local location = Model.parse(message.From)
		local instance = if location then Model.get(record.Inventory, location) else nil
		local definition = if instance then Rules.definition(instance.ItemId) else nil
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if location and instance and definition and definition.Droppable ~= false and root and root:IsA("BasePart") then
			local taken = Model.take(record.Inventory, location)
			if taken then
				dropInWorld(taken, root.Position + root.CFrame.LookVector * 3, player.UserId)
				ok = true
			end
		else
			reason = "CannotDrop"
		end
	end
	if ok then
		publish(player)
	elseif remote then
		remote:FireClient(player, { Kind = "Rejected", Op = op, Reason = reason })
	end
end

function Inventory.start(folder: Folder)
	local existing = folder:FindFirstChild(Protocol.Inventory)
	local event = if existing and existing:IsA("RemoteEvent") then existing else Instance.new("RemoteEvent")
	event.Name = Protocol.Inventory
	event.Parent = folder
	remote = event
	event.OnServerEvent:Connect(handle)

	local loot = Instance.new("Folder")
	loot.Name = "LootDrops"
	loot.Parent = workspace
	lootFolder = loot

	Damage.Applied:Connect(function(attacker: Model, target: Humanoid, _amount: number, killed: boolean)
		local model = target.Parent
		if not killed or not model or not model:IsA("Model") or not CollectionService:HasTag(model, "Enfleshed") then
			return
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return
		end
		local killer = Players:GetPlayerFromCharacter(attacker)
		local ownerUserId = if killer then killer.UserId else attacker:GetAttribute("MagicSummonOwnerUserId")
		local role = model:GetAttribute("MissionRole")
		Inventory.dropLoot(if type(role) == "string" then role else "Basic", root.Position, ownerUserId)
	end)
end

return Inventory
