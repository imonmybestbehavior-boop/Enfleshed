--!strict

-- Server-owned active-weapon state on top of InventoryService. It selects items
-- and profiles but never executes weapon combat; magic remains in MagicService
-- and melee in CombatService. Legacy slot names map onto inventory equip slots:
-- PrimaryWeapon = MagicFocus, SecondaryWeapon = MainHand melee weapon.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Configuration.Items)
local Rules = require(Shared.Modules.ItemRules)
local Inventory = require(script.Parent.InventoryService)
local Equipment = {}

type Slot = "PrimaryWeapon" | "SecondaryWeapon" | "Utility"
type State = { ActiveSlot: Slot, VisualUid: string? }

local equipSlotFor: { [string]: string } = { PrimaryWeapon = "MagicFocus", SecondaryWeapon = "MainHand" }
local states: { [Player]: State } = {}
local feedbackRemote: RemoteEvent? = nil

local function itemInSlot(player: Player, slot: Slot): Rules.Instance?
	local equipSlot = equipSlotFor[slot]
	return if equipSlot then Inventory.equipped(player, equipSlot) else nil
end

local function publish(player: Player, state: State)
	local primary = itemInSlot(player, "PrimaryWeapon")
	local secondary = itemInSlot(player, "SecondaryWeapon")
	player:SetAttribute("PrimaryWeapon", if primary then primary.ItemId else nil)
	player:SetAttribute("SecondaryWeapon", if secondary then secondary.ItemId else nil)
	player:SetAttribute("ActiveEquipmentSlot", state.ActiveSlot)
	if feedbackRemote then
		feedbackRemote:FireClient(player, {
			Kind = "Equipment",
			PrimaryWeapon = if primary then primary.ItemId else nil,
			SecondaryWeapon = if secondary then secondary.ItemId else nil,
			ActiveSlot = state.ActiveSlot,
		})
	end
end

local function attachVisual(player: Player, state: State)
	local character = player.Character
	if not character then
		return
	end
	local active = itemInSlot(player, state.ActiveSlot)
	local previous = character:FindFirstChild("SandboxEquippedWeapon")
	if previous and active and state.VisualUid == active.Uid then
		return
	end
	if previous then
		previous:Destroy()
	end
	state.VisualUid = nil
	local item = if active then Definitions.Items[active.ItemId] else nil
	if not item or not item.Visual then
		return
	end
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end
	local visual = item.Visual
	local part = Instance.new("Part")
	part.Name = "SandboxEquippedWeapon"
	part.Size = visual.Size
	part.Color = visual.Color
	part.Material = visual.Material
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CFrame = hand.CFrame * visual.Offset
	part:SetAttribute("ItemUid", (active :: Rules.Instance).Uid)
	part.Parent = character
	if visual.MuzzleOffset then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.CFrame = visual.MuzzleOffset
		muzzle.Parent = part
	end
	local rarity = Rules.rarity((active :: Rules.Instance).Rarity)
	if rarity.Affixes > 0 then
		local glow = Instance.new("PointLight")
		glow.Color = rarity.Color
		glow.Range = 4
		glow.Brightness = 0.8
		glow.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
	state.VisualUid = (active :: Rules.Instance).Uid
end

local function refresh(player: Player)
	local state = states[player]
	if not state then
		return
	end
	if not itemInSlot(player, state.ActiveSlot) then
		local other: Slot = if state.ActiveSlot == "PrimaryWeapon" then "SecondaryWeapon" else "PrimaryWeapon"
		if itemInSlot(player, other) then
			state.ActiveSlot = other
		end
	end
	local character = player.Character
	if character then
		character:SetAttribute("ArmorReduction", Inventory.armor(player))
	end
	attachVisual(player, state)
	publish(player, state)
end

function Equipment.start(feedback: RemoteEvent)
	feedbackRemote = feedback
	Inventory.Changed:Connect(refresh)
end

function Equipment.bind(player: Player)
	states[player] = { ActiveSlot = "SecondaryWeapon" } -- Preserve existing melee controls on spawn.
	task.spawn(Inventory.bind, player)
end

-- Sandbox entry prefers a path's weapon when the inventory has one equipped.
function Equipment.chooseStarter(player: Player, path: string, _remote: RemoteEvent?): boolean
	local state = states[player]
	if not state or (path ~= "Melee" and path ~= "Magic") then
		return false
	end
	local slot: Slot = if path == "Melee" then "SecondaryWeapon" else "PrimaryWeapon"
	-- While the inventory is still loading, remember the preference; refresh
	-- keeps it once the matching item arrives.
	if Inventory.ready(player) and not itemInSlot(player, slot) then
		return false
	end
	state.ActiveSlot = slot
	refresh(player)
	return true
end

function Equipment.characterAdded(player: Player, _remote: RemoteEvent?)
	local state = states[player]
	if state then
		state.VisualUid = nil
		refresh(player)
	end
end

function Equipment.switch(player: Player, slot: any, _remote: RemoteEvent?): boolean
	local state = states[player]
	if not state or (slot ~= "PrimaryWeapon" and slot ~= "SecondaryWeapon") then
		return false
	end
	if not itemInSlot(player, slot :: Slot) then
		return false
	end
	state.ActiveSlot = slot
	refresh(player)
	return true
end

function Equipment.magicCast(player: Player, action: any): (string?, { Origin: Vector3 }?)
	local state = states[player]
	if not state or state.ActiveSlot ~= "PrimaryWeapon" or (action ~= "Primary" and action ~= "Area") then
		return nil, nil
	end
	local instance = itemInSlot(player, "PrimaryWeapon")
	local item = if instance then Definitions.Items[instance.ItemId] else nil
	if not item or item.ItemType ~= "Weapon" or item.WeaponType ~= "MagicFocus" then
		return nil, nil
	end
	local weapon = player.Character and player.Character:FindFirstChild("SandboxEquippedWeapon")
	local muzzle = if weapon then weapon:FindFirstChild("Muzzle") else nil
	local context = if muzzle and muzzle:IsA("Attachment") then { Origin = muzzle.WorldPosition } else nil
	local spellId = if action == "Primary" then item.PrimarySpellId else item.AreaSpellId
	if type(spellId) ~= "string" then
		return nil, nil
	end
	return spellId, context
end

function Equipment.freeHandCount(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local character = player.Character
	local handCount = 2
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rigHandCount = humanoid and humanoid:GetAttribute("MagicHandCount")
	if type(rigHandCount) == "number" and rigHandCount == rigHandCount then
		handCount = math.clamp(math.floor(rigHandCount), 0, 8)
	end
	local instance = itemInSlot(player, state.ActiveSlot)
	local item = if instance then Definitions.Items[instance.ItemId] else nil
	local occupied = if item then item.HandsOccupied else 0
	if type(occupied) ~= "number" or occupied ~= occupied then
		occupied = if item and item.ItemType == "Weapon" then 1 else 0
	end
	return math.max(0, handCount - math.clamp(math.floor(occupied), 0, handCount))
end

-- Resolved melee profile of the active weapon, or nil when melee is not active.
function Equipment.meleeLoadout(player: Player): any?
	local state = states[player]
	if not state or state.ActiveSlot ~= "SecondaryWeapon" then
		return nil
	end
	return Rules.meleeLoadout(itemInSlot(player, "SecondaryWeapon"))
end

function Equipment.meleeActive(player: Player): boolean
	return Equipment.meleeLoadout(player) ~= nil
end

function Equipment.remove(player: Player)
	states[player] = nil
	Inventory.remove(player)
end

return Equipment
