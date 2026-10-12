--!strict

-- Server-owned prototype equipment state. It selects items/profiles but never
-- executes weapon combat; magic remains in MagicService and melee in CombatService.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Definitions = require(Shared.Configuration.Items)
local Equipment = {}

type Slot = "PrimaryWeapon" | "SecondaryWeapon" | "Utility"
type State = {
	Owned: { [string]: boolean },
	PrimaryWeapon: string?,
	SecondaryWeapon: string?,
	Utility: string?,
	ActiveSlot: Slot,
}

local states: { [Player]: State } = {}

local function itemInSlot(state: State, slot: Slot): string?
	return state[slot]
end

local function publish(player: Player, state: State, remote: RemoteEvent)
	player:SetAttribute("PrimaryWeapon", state.PrimaryWeapon)
	player:SetAttribute("SecondaryWeapon", state.SecondaryWeapon)
	player:SetAttribute("Utility", state.Utility)
	player:SetAttribute("ActiveEquipmentSlot", state.ActiveSlot)
	remote:FireClient(player, {
		Kind = "Equipment",
		PrimaryWeapon = state.PrimaryWeapon,
		SecondaryWeapon = state.SecondaryWeapon,
		Utility = state.Utility,
		ActiveSlot = state.ActiveSlot,
	})
end

local function attachVisual(player: Player, state: State)
	local character = player.Character
	if not character then
		return
	end
	local previous = character:FindFirstChild("SandboxEquippedWeapon")
	if previous then
		previous:Destroy()
	end
	local itemId = itemInSlot(state, state.ActiveSlot)
	local item = if itemId then Definitions.Items[itemId] else nil
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
	part.Parent = character
	if visual.MuzzleOffset then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.CFrame = visual.MuzzleOffset
		muzzle.Parent = part
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = part
	weld.Parent = part
end

function Equipment.bind(player: Player)
	states[player] = {
		Owned = {},
		PrimaryWeapon = nil,
		SecondaryWeapon = nil,
		Utility = nil,
		ActiveSlot = "SecondaryWeapon", -- Preserve existing melee controls on spawn.
	}
end

function Equipment.chooseStarter(player: Player, path: string, remote: RemoteEvent): boolean
	local state = states[player]
	if not state or next(state.Owned) ~= nil or (path ~= "Melee" and path ~= "Magic") then
		return false
	end
	local id = if path == "Melee" then "RecruitMeleeWeapon" else "RecruitMagicWeapon"
	local slot: Slot = if path == "Melee" then "SecondaryWeapon" else "PrimaryWeapon"
	state.Owned[id] = true
	state[slot] = id
	state.ActiveSlot = slot
	attachVisual(player, state)
	publish(player, state, remote)
	return true
end

function Equipment.characterAdded(player: Player, remote: RemoteEvent)
	local state = states[player]
	if state then
		attachVisual(player, state)
		publish(player, state, remote)
	end
end

function Equipment.switch(player: Player, slot: any, remote: RemoteEvent): boolean
	local state = states[player]
	if slot ~= "PrimaryWeapon" and slot ~= "SecondaryWeapon" and slot ~= "Utility" then
		return false
	end
	if not state then
		return false
	end
	local itemId = itemInSlot(state, slot :: Slot)
	if not itemId or not state.Owned[itemId] or not Definitions.Items[itemId] then
		return false
	end
	state.ActiveSlot = slot
	attachVisual(player, state)
	publish(player, state, remote)
	return true
end

function Equipment.magicCast(player: Player, action: any): (string?, { Origin: Vector3 }?)
	local state = states[player]
	if not state or state.ActiveSlot ~= "PrimaryWeapon" or (action ~= "Primary" and action ~= "Area") then
		return nil, nil
	end
	local itemId = state.PrimaryWeapon
	local item = if itemId and state.Owned[itemId] then Definitions.Items[itemId] else nil
	if not item or item.ItemType ~= "Weapon" or item.WeaponType ~= "MagicFocus" then
		return nil, nil
	end
	local selectedProfileId = require(script.Parent.MagicDiscoveryService).awakeningProfileId(player)
	local profileId = selectedProfileId or item.MagicProfile
	local profile = Definitions.MagicProfiles[profileId]
	if not profile then
		return nil, nil
	end
	local weapon = player.Character and player.Character:FindFirstChild("SandboxEquippedWeapon")
	local muzzle = if weapon then weapon:FindFirstChild("Muzzle") else nil
	local context = if muzzle and muzzle:IsA("Attachment") then { Origin = muzzle.WorldPosition } else nil
	return if action == "Primary" then profile.PrimarySpellId else profile.AreaSpellId, context
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
	local itemId = itemInSlot(state, state.ActiveSlot)
	local item = if itemId and state.Owned[itemId] then Definitions.Items[itemId] else nil
	local occupied = if item then item.HandsOccupied else 0
	if type(occupied) ~= "number" or occupied ~= occupied then
		occupied = if item and item.ItemType == "Weapon" then 1 else 0
	end
	return math.max(0, handCount - math.clamp(math.floor(occupied), 0, handCount))
end

function Equipment.meleeActive(player: Player): boolean
	local state = states[player]
	if not state or state.ActiveSlot ~= "SecondaryWeapon" then
		return false
	end
	local itemId = state.SecondaryWeapon
	local item = if itemId and state.Owned[itemId] then Definitions.Items[itemId] else nil
	return item ~= nil and item.ItemType == "Weapon" and item.WeaponType == "Melee"
end

function Equipment.remove(player: Player)
	states[player] = nil
end

return Equipment
