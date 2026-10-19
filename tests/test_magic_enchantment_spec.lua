-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicEnchantmentSpec.luau"))()

local polarity = {
	Heal = "Boon",
	Shield = "Boon",
	Enhancement = "Boon",
	Damage = "Bane",
	Slow = "Bane",
	ElementalMark = "Bane",
	Reveal = "Neutral",
}
local function polarityOf(kind)
	return polarity[kind]
end
local function def(...)
	local payloads = {}
	for _, kind in ipairs({ ... }) do
		table.insert(payloads, { Kind = kind })
	end
	return { Triggers = { OnCast = { { Payloads = payloads } } } }
end

-- Type: any Bane wins, then any Boon, else Neutral.
assert(Spec.typeOf(def("Heal", "Shield"), polarityOf) == "Boon")
assert(Spec.typeOf(def("Heal", "Slow"), polarityOf) == "Bane", "a single Bane makes it a Bane")
assert(Spec.typeOf(def("Reveal"), polarityOf) == "Neutral")
assert(Spec.typeOf({ Triggers = {} }, polarityOf) == "Neutral")

-- Keys: one per spell per holder; self casts keep the SpellId.
assert(Spec.key("Slot1", "7", true) == "Slot1")
assert(Spec.key("Slot1", "7", false) == "Slot1@7")
assert(Spec.key("Slot1", "8", false) ~= Spec.key("Slot1", "7", false))

-- Identity: the same spell from two casters is the same Enchantment; cosmetic
-- fields (slot id, name, visuals, audio, tags) and runtime "_" keys do not count.
local blessA = def("Heal", "Shield")
blessA.SpellId, blessA.Name, blessA.Visual = "MagicLabSlot1", "Blessing", { Color = "gold" }
local blessB = def("Heal", "Shield")
blessB.SpellId, blessB.Name, blessB._VFXCaster = "MagicLabSlot4", "My blessing", {}
assert(Spec.identity(blessA) == Spec.identity(blessB), "same content, different slots and names")
local stronger = def("Heal", "Shield")
stronger.Triggers.OnCast[1].Payloads[1].Amount = 40
assert(Spec.identity(stronger) ~= Spec.identity(blessA), "different numbers are a different Enchantment")

-- Caps: the same Enchantment stacks 3 times from different casters; the same
-- caster refreshes; different Enchantments never limit each other.
local bless, hex = Spec.identity(blessA), Spec.identity(def("Slow"))
local existing = {
	{ Owner = "1", Key = "Slot1@7", Identity = bless },
	{ Owner = "2", Key = "Slot4@7", Identity = bless },
	{ Owner = "3", Key = "Slot2@7", Identity = bless },
	{ Owner = "1", Key = "Slot3@7", Identity = hex },
}
local ok, reason, refreshKey = Spec.canAdd(existing, "4", bless, 3)
assert(not ok and string.find(reason, "3 times", 1, true), "a fourth caster's copy is refused")
ok, reason, refreshKey = Spec.canAdd(existing, "2", bless, 3)
assert(ok and refreshKey == "Slot4@7", "the same caster recasting refreshes their copy")
ok, reason, refreshKey = Spec.canAdd(existing, "4", hex, 3)
assert(ok and refreshKey == nil, "a different Enchantment is not limited by the blessings")
local many = {}
for owner = 1, 20 do
	table.insert(many, { Owner = tostring(owner), Key = "S@7", Identity = "spell" .. owner })
end
assert(Spec.canAdd(many, "99", bless, 3), "no total cap per character")

-- Lifecycle: holder death first, then holder gone, owner death, duration.
local record = { ExpiresAt = 10 }
local function facts(overrides)
	local f = { Now = 5, HolderAlive = true, HolderPresent = true, OwnerAlive = true, OwnerPresent = true }
	for key, value in pairs(overrides) do
		f[key] = value
	end
	return f
end
assert(Spec.endReason(record, facts({})) == nil)
assert(Spec.endReason(record, facts({ Now = 10 })) == "Duration")
assert(Spec.endReason(record, facts({ HolderAlive = false, Now = 99 })) == "HolderDeath")
assert(Spec.endReason(record, facts({ HolderPresent = false, OwnerAlive = false })) == "HolderGone")
assert(Spec.endReason(record, facts({ OwnerAlive = false })) == "OwnerDeath")
assert(Spec.endReason(record, facts({ OwnerPresent = false })) == "OwnerDeath", "owner respawned")

local function same(a, b)
	return table.concat(a, ",") == table.concat(b, ",")
end
assert(same(Spec.endEvents("HolderDeath", false), { "OnTargetDeath", "OnExpire" }), "owner hears of holder death")
assert(same(Spec.endEvents("HolderDeath", true), { "OnCasterDeath", "OnExpire" }), "self: your own death")
assert(same(Spec.endEvents("OwnerDeath", false), { "OnCasterDeath", "OnExpire" }))
assert(same(Spec.endEvents("Duration", false), { "OnExpire" }))
assert(same(Spec.endEvents("Toggle", false), { "OnExpire" }))
assert(same(Spec.endEvents("HolderGone", true), { "OnExpire" }), "respawn is not a death")

-- Movement on others: Swiftness for player holders, Aerial only on yourself.
local self = Spec.movement(true, true)
assert(self.Swiftness and self.Aerial)
local ally = Spec.movement(false, true)
assert(ally.Swiftness and not ally.Aerial)
local npc = Spec.movement(false, false)
assert(not npc.Swiftness and not npc.Aerial)

-- Overhead summary round-trips.
assert(Spec.encode({ "Bane", "Boon", "Boon" }) == "Boon:2|Bane:1")
assert(Spec.encode({}) == "")
local counts = Spec.decode("Boon:2|Bane:1")
assert(counts.Boon == 2 and counts.Bane == 1 and counts.Neutral == nil)
assert(next(Spec.decode(nil)) == nil)
print("Magic enchantment spec: owner/holder keys, type caps, lifecycle events and summary passed")
