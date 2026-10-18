-- Inventory container and item-rule behaviour (run via scripts/run_luau_inventory_tests.py).
local Rules = loadModule("Modules/ItemRules")
local Model = loadModule("Modules/InventoryModel")
local Items = loadModule("Configuration/Items").Items
local Loot = loadModule("Configuration/Loot")
local Melee = loadModule("Configuration/MeleeProfiles")

local serial = 0
local function uid()
	serial += 1
	return "uid-" .. serial
end

-- Every item definition is coherent.
for id, item in Items do
	assert(item.ItemId == id, id .. " ItemId mismatch")
	assert(type(item.Name) == "string", id .. " needs a Name")
	assert(
		item.Category == "Weapon"
			or item.Category == "Armor"
			or item.Category == "Consumable"
			or item.Category == "Material",
		id
	)
	if item.WeaponType == "Melee" then
		assert(Melee.Profiles[item.Archetype], id .. " has unknown archetype")
		assert(item.EquipSlot == "MainHand", id)
	end
	if item.Category == "Consumable" or item.Category == "Material" then
		assert(item.MaxStack > 1, id .. " should stack")
	end
end
for role, tableDef in Loot.Tables do
	for _, entry in tableDef.Entries do
		assert(Items[entry.ItemId], role .. " drops unknown " .. entry.ItemId)
	end
end

-- Rolling respects rarity affix counts and categories, and is seed-deterministic.
local rng = Random.new(7)
local seenRarities = {}
for _ = 1, 400 do
	local instance = assert(Rules.roll("WallwardLongsword", rng, uid(), 2))
	seenRarities[instance.Rarity] = true
	assert(#instance.Affixes == Rules.rarity(instance.Rarity).Affixes)
	local ids = {}
	for _, affix in instance.Affixes do
		assert(not ids[affix.Id], "duplicate affix")
		ids[affix.Id] = true
		assert(Loot.Affixes[affix.Id].Categories.Weapon)
	end
end
assert(seenRarities.Common and seenRarities.Relic, "bonus rolls should span rarities")
local a = Rules.roll("PaddedGambeson", Random.new(3), "x", 1)
local b = Rules.roll("PaddedGambeson", Random.new(3), "x", 1)
assert(a.Rarity == b.Rarity and #a.Affixes == #b.Affixes)
local tissue = Rules.roll("EnfleshedTissue", rng, uid(), 2, 999)
assert(tissue.Rarity == "Common" and #tissue.Affixes == 0 and tissue.Count == Items.EnfleshedTissue.MaxStack)

-- Affixes change resolved melee numbers.
local plain = Rules.meleeLoadout(Rules.new("RecruitMeleeWeapon", uid()))
assert(#plain.Lights == #Melee.Profiles.Sword.Lights)
assert(plain.Lights[1].Damage == Melee.Profiles.Sword.Lights[1].Damage)
local keen = Rules.meleeLoadout(Rules.new("RecruitMeleeWeapon", uid(), 1, "Rare", {
	{ Id = "Keen", Value = 0.5 },
	{ Id = "Swift", Value = 0.25 },
}))
assert(keen.Lights[1].Damage > plain.Lights[1].Damage)
assert(keen.Lights[1].Startup < plain.Lights[1].Startup)
assert(Rules.meleeLoadout(Rules.new("FieldDressing", uid())) == nil)
assert(Rules.meleeLoadout(Rules.new("BreachersGreatsword", uid())).HandsOccupied == 2)
assert(Rules.armor({ Rules.new("GuardHalfHelm", uid()), Rules.new("PaddedGambeson", uid()) }) > 0.1)

-- Move, swap, stack and equip rules.
local inv = Model.blank()
inv.Bag[1] = Rules.new("ThornKnife", uid())
inv.Bag[2] = Rules.new("FieldDressing", uid(), 4)
inv.Bag[3] = Rules.new("FieldDressing", uid(), 9)
inv.Equip.MainHand = Rules.new("RecruitMeleeWeapon", uid())
assert(not Model.move(inv, "Bag:2", "Equip:MainHand"), "consumable cannot be wielded")
assert(not Model.move(inv, "Bag:1", "Equip:Head"), "knife is not a helm")
assert(not Model.move(inv, "Bag:1", "Quick:1"), "weapons do not go in quick slots")
assert(Model.move(inv, "Bag:1", "Equip:MainHand"), "equip swaps")
assert(inv.Equip.MainHand.ItemId == "ThornKnife" and inv.Bag[1].ItemId == "RecruitMeleeWeapon")
assert(Model.move(inv, "Bag:2", "Bag:3"), "merge stacks")
assert(inv.Bag[3].Count == 10 and inv.Bag[2].Count == 3)
assert(Model.move(inv, "Bag:2", "Quick:1"))
assert(inv.Quick[1].Count == 3 and inv.Bag[2] == nil)
assert(not Model.move(inv, "Bag:99", "Bag:1") and not Model.move(inv, "Equip:Nope", "Bag:1"))
assert(not Model.move(inv, "Bag:4", "Bag:1"), "empty source")

-- Split and add.
assert(Model.split(inv, "Bag:3", 4, uid()))
assert(inv.Bag[3].Count == 6 and inv.Bag[2].Count == 4)
assert(not Model.split(inv, "Bag:3", 6, uid()), "cannot split a whole stack")
assert(Model.add(inv, Rules.new("FieldDressing", uid(), 5)) == 0)
assert(inv.Quick[1].Count == 8, "add tops up quick-slot stacks first")
local full = Model.blank()
for index = 1, Model.BagSize do
	full.Bag[index] = Rules.new("ThornKnife", uid())
end
assert(Model.add(full, Rules.new("LinePike", uid())) == 1, "full bag rejects")

-- Serialisation round trip, and untrusted data is cleaned.
local restored = Model.deserialize(Model.serialize(inv))
assert(restored.Equip.MainHand.ItemId == "ThornKnife")
assert(restored.Quick[1].Count == 8 and restored.Bag[3].Count == 6)
local hostile = Model.deserialize({
	{ Uid = "a", ItemId = "NotReal", Location = "Bag:1" },
	{ Uid = "b", ItemId = "FieldDressing", Count = 9999, Location = "Equip:MainHand" },
	{
		Uid = "c",
		ItemId = "ThornKnife",
		Rarity = "Relic",
		Affixes = { { Id = "Keen", Value = 50 }, { Id = "Warding", Value = 1 } },
		Location = "Bag:2",
	},
	{ Uid = "c", ItemId = "ThornKnife", Location = "Bag:3" },
})
assert(hostile.Bag[1] and hostile.Bag[1].ItemId == "FieldDressing", "misplaced item falls back to the bag")
assert(hostile.Bag[1].Count == Items.FieldDressing.MaxStack)
local knife = hostile.Bag[2]
assert(#knife.Affixes == 1 and knife.Affixes[1].Value <= Loot.Affixes.Keen.Max * 2, "affixes clamped and filtered")
assert(hostile.Bag[3] == nil, "duplicate uid dropped")

print("inventory specs passed")
