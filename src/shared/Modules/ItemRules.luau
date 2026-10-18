--!strict

-- Pure item-instance rules shared by server authority and client presentation:
-- loot rolling, stat aggregation, melee profile resolution and save cleaning.
-- An item instance is { Uid, ItemId, Count, Rarity, Affixes = { { Id, Value } } }.
local Configuration = script.Parent.Parent.Configuration
local Items = require(Configuration.Items).Items
local Loot = require(Configuration.Loot)
local Melee = require(Configuration.MeleeProfiles)

local Rules = {}

export type Affix = { Id: string, Value: number }
export type Instance = {
	Uid: string,
	ItemId: string,
	Count: number,
	Rarity: string,
	Affixes: { Affix },
}

local rarityIndex: { [string]: number } = {}
for index, rarity in Loot.Rarities do
	rarityIndex[rarity.Id] = index
end

function Rules.definition(itemId: any): any?
	return if type(itemId) == "string" then Items[itemId] else nil
end

function Rules.rarity(id: string): any
	return Loot.Rarities[rarityIndex[id] or 1]
end

function Rules.rollable(definition: any): boolean
	return definition ~= nil
		and ((definition.Category == "Weapon" and definition.WeaponType == "Melee") or definition.Category == "Armor")
end

function Rules.maxStack(definition: any): number
	return math.max(1, if definition and type(definition.MaxStack) == "number" then definition.MaxStack else 1)
end

function Rules.canStack(a: Instance?, b: Instance?): boolean
	if not a or not b or a.ItemId ~= b.ItemId or #a.Affixes > 0 or #b.Affixes > 0 then
		return false
	end
	return Rules.maxStack(Rules.definition(a.ItemId)) > 1
end

function Rules.new(itemId: string, uid: string, count: number?, rarity: string?, affixes: { Affix }?): Instance
	return {
		Uid = uid,
		ItemId = itemId,
		Count = count or 1,
		Rarity = rarity or "Common",
		Affixes = affixes or {},
	}
end

local function pickRarity(rng: Random, bonus: number): string
	local total = 0
	local weights = {}
	for index, rarity in Loot.Rarities do
		local weight = rarity.Weight * (1 + bonus * 0.5) ^ (index - 1)
		weights[index] = weight
		total += weight
	end
	local roll = rng:NextNumber() * total
	for index, weight in weights do
		roll -= weight
		if roll <= 0 then
			return Loot.Rarities[index].Id
		end
	end
	return Loot.Rarities[#Loot.Rarities].Id
end

local function round(value: number): number
	return math.floor(value * 1000 + 0.5) / 1000
end

-- Rolls one instance. Non-rollable items (consumables, materials, focus) are Common with no affixes.
function Rules.roll(itemId: string, rng: Random, uid: string, rarityBonus: number?, count: number?): Instance?
	local definition = Items[itemId]
	if not definition then
		return nil
	end
	if not Rules.rollable(definition) then
		return Rules.new(itemId, uid, math.clamp(count or 1, 1, Rules.maxStack(definition)))
	end
	local rarity = pickRarity(rng, rarityBonus or 0)
	local pool = {}
	for id, affix in Loot.Affixes do
		if affix.Categories[definition.Category] then
			table.insert(pool, id)
		end
	end
	table.sort(pool) -- Deterministic order so seeded rolls are reproducible.
	local affixes = {}
	local scale = Loot.RarityScale[rarity] or 1
	for _ = 1, math.min(Rules.rarity(rarity).Affixes, #pool) do
		local id = table.remove(pool, rng:NextInteger(1, #pool))
		local affix = Loot.Affixes[id]
		table.insert(
			affixes,
			{ Id = id, Value = round((affix.Min + (affix.Max - affix.Min) * rng:NextNumber()) * scale) }
		)
	end
	return Rules.new(itemId, uid, 1, rarity, affixes)
end

-- Picks loot from a role's table. Returns a list of { ItemId, Count, RarityBonus }.
function Rules.rollDrops(role: string, rng: Random): { { ItemId: string, Count: number, RarityBonus: number } }
	local tableDef = Loot.Tables[role] or Loot.Tables.Basic
	local drops = {}
	if rng:NextNumber() > tableDef.Chance then
		return drops
	end
	local total = 0
	for _, entry in tableDef.Entries do
		total += entry.Weight
	end
	for _ = 1, tableDef.Rolls do
		local roll = rng:NextNumber() * total
		for _, entry in tableDef.Entries do
			roll -= entry.Weight
			if roll <= 0 then
				local count = if entry.Count then rng:NextInteger(entry.Count[1], entry.Count[2]) else 1
				table.insert(drops, { ItemId = entry.ItemId, Count = count, RarityBonus = tableDef.RarityBonus })
				break
			end
		end
	end
	return drops
end

function Rules.stats(instance: Instance?): { [string]: number }
	local result: { [string]: number } = {}
	if not instance then
		return result
	end
	for _, affix in instance.Affixes do
		local definition = Loot.Affixes[affix.Id]
		if definition then
			result[definition.Stat] = (result[definition.Stat] or 0) + affix.Value
		end
	end
	return result
end

local function scaleAttack(attack: any, damage: number, speed: number, reach: number): any
	return {
		Startup = attack.Startup / speed,
		Active = attack.Active,
		Recovery = attack.Recovery / speed,
		Damage = math.floor(attack.Damage * damage + 0.5),
		Size = Vector3.new(attack.Size.X, attack.Size.Y, attack.Size.Z * reach),
		Offset = attack.Offset * (1 + (reach - 1) * 0.5),
		Reach = attack.Reach * reach,
		Reaction = attack.Reaction,
	}
end

-- Resolves an equipped melee instance into concrete attack timings and guard values.
function Rules.meleeLoadout(instance: Instance?): any?
	local definition = if instance then Items[instance.ItemId] else nil
	if not definition or definition.WeaponType ~= "Melee" then
		return nil
	end
	local profile = Melee.Profiles[definition.Archetype or "Sword"]
	if not profile then
		return nil
	end
	local stats = Rules.stats(instance)
	local damage = (definition.DamageScale or 1) * (1 + (stats.Damage or 0))
	local speed = (definition.SpeedScale or 1) * (1 + (stats.AttackSpeed or 0))
	local reach = 1 + (stats.Reach or 0)
	local lights = {}
	for index, attack in profile.Lights do
		lights[index] = scaleAttack(attack, damage, speed, reach)
	end
	return {
		Archetype = definition.Archetype,
		HandsOccupied = definition.HandsOccupied or 1,
		Lights = lights,
		Heavy = scaleAttack(profile.Heavy, damage * (1 + (stats.HeavyDamage or 0)), speed, reach),
		Block = {
			Reduction = math.clamp(profile.Block.Reduction + (stats.BlockReduction or 0), 0, 0.95),
			ParryWindow = profile.Block.ParryWindow + (stats.ParryWindow or 0),
			FacingDot = profile.Block.FacingDot,
		},
	}
end

function Rules.armor(instances: { Instance? }): number
	local total = 0
	for _, instance in instances do
		local definition = if instance then Items[instance.ItemId] else nil
		if definition and definition.Category == "Armor" then
			total += (definition.Armor or 0) + (Rules.stats(instance).Armor or 0)
		end
	end
	return math.clamp(total, 0, Loot.MaxArmor)
end

function Rules.displayName(instance: Instance): string
	local definition = Items[instance.ItemId]
	local name = if definition then definition.Name or instance.ItemId else instance.ItemId
	local first = instance.Affixes[1]
	local affix = if first then Loot.Affixes[first.Id] else nil
	return if affix then affix.Name .. " " .. name else name
end

local function formatAffix(affix: Affix): string?
	local definition = Loot.Affixes[affix.Id]
	if not definition then
		return nil
	end
	local labels = {
		Damage = "damage",
		AttackSpeed = "attack speed",
		Reach = "reach",
		HeavyDamage = "heavy damage",
		ParryWindow = "parry window",
		BlockReduction = "block reduction",
		Armor = "damage reduction",
	}
	local label = labels[definition.Stat] or definition.Stat
	if definition.Kind == "Seconds" then
		return string.format("+%.2fs %s", affix.Value, label)
	end
	return string.format("+%d%% %s", math.floor(affix.Value * 100 + 0.5), label)
end

-- Tooltip content: title, colour, and ordered text lines.
function Rules.describe(
	instance: Instance
): { Title: string, Color: Color3, Subtitle: string, Lines: { string }, Description: string }
	local definition = Items[instance.ItemId] or {}
	local rarity = Rules.rarity(instance.Rarity)
	local lines = {}
	local subtitle = definition.Category or "Item"
	if definition.WeaponType == "Melee" then
		local loadout = Rules.meleeLoadout(instance)
		subtitle = string.format(
			"%s %s · %s",
			rarity.Name,
			definition.Archetype or "Weapon",
			if definition.HandsOccupied == 2 then "Two-handed" else "One-handed"
		)
		if loadout then
			local lightTotal = 0
			for _, attack in loadout.Lights do
				lightTotal += attack.Damage
			end
			table.insert(lines, string.format("Light combo: %d hits, %d total", #loadout.Lights, lightTotal))
			table.insert(lines, string.format("Heavy: %d damage", loadout.Heavy.Damage))
			table.insert(lines, string.format("Reach: %.1f", loadout.Lights[1].Reach))
			table.insert(
				lines,
				string.format(
					"Block: %d%%  Parry: %.2fs",
					math.floor(loadout.Block.Reduction * 100 + 0.5),
					loadout.Block.ParryWindow
				)
			)
		end
	elseif definition.WeaponType == "MagicFocus" then
		subtitle = "Magic Focus"
		table.insert(lines, "Casts your awakened magic profile")
	elseif definition.Category == "Armor" then
		subtitle = string.format("%s %s armour", rarity.Name, definition.EquipSlot or "")
		table.insert(lines, string.format("Damage reduction: %d%%", math.floor((definition.Armor or 0) * 100 + 0.5)))
	elseif definition.Category == "Consumable" then
		subtitle = "Consumable"
		if definition.Heal then
			table.insert(lines, string.format("Restores %d health", definition.Heal))
		end
	elseif definition.Category == "Material" then
		subtitle = "Material"
	end
	for _, affix in instance.Affixes do
		local text = formatAffix(affix)
		if text then
			table.insert(lines, text)
		end
	end
	if instance.Count > 1 then
		table.insert(lines, string.format("Stack: %d / %d", instance.Count, Rules.maxStack(definition)))
	end
	return {
		Title = Rules.displayName(instance),
		Color = rarity.Color,
		Subtitle = subtitle,
		Lines = lines,
		Description = definition.Description or "",
	}
end

-- Validates untrusted (saved) data back into an instance, or nil when unusable.
function Rules.clean(raw: any): Instance?
	if type(raw) ~= "table" or type(raw.Uid) ~= "string" or #raw.Uid == 0 or #raw.Uid > 64 then
		return nil
	end
	local definition = Rules.definition(raw.ItemId)
	if not definition then
		return nil
	end
	local count = if type(raw.Count) == "number" and raw.Count == raw.Count then math.floor(raw.Count) else 1
	count = math.clamp(count, 1, Rules.maxStack(definition))
	local rarity = if type(raw.Rarity) == "string" and rarityIndex[raw.Rarity] then raw.Rarity else "Common"
	local affixes = {}
	if Rules.rollable(definition) and type(raw.Affixes) == "table" then
		local seen = {}
		local maxScale = 1
		for _, scale in Loot.RarityScale do
			maxScale = math.max(maxScale, scale)
		end
		for _, affix in raw.Affixes do
			local affixDef = if type(affix) == "table" and type(affix.Id) == "string"
				then Loot.Affixes[affix.Id]
				else nil
			if
				affixDef
				and not seen[affix.Id]
				and affixDef.Categories[definition.Category]
				and type(affix.Value) == "number"
				and affix.Value == affix.Value
				and #affixes < 4
			then
				seen[affix.Id] = true
				table.insert(affixes, { Id = affix.Id, Value = math.clamp(affix.Value, 0, affixDef.Max * maxScale) })
			end
		end
	end
	if not Rules.rollable(definition) then
		rarity = "Common"
	end
	return Rules.new(raw.ItemId, raw.Uid, count, rarity, affixes)
end

function Rules.copy(instance: Instance): Instance
	local affixes = {}
	for index, affix in instance.Affixes do
		affixes[index] = { Id = affix.Id, Value = affix.Value }
	end
	return Rules.new(instance.ItemId, instance.Uid, instance.Count, instance.Rarity, affixes)
end

return Rules
