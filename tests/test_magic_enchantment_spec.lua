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

-- Caps: 3 per type, refresh always allowed, total cap.
local existing = {
	{ Key = "1:A@7", Type = "Boon" },
	{ Key = "2:B@7", Type = "Boon" },
	{ Key = "3:C@7", Type = "Boon" },
	{ Key = "1:D@7", Type = "Bane" },
}
local ok, reason = Spec.canAdd(existing, "4:E@7", "Boon", 3, 9)
assert(not ok and string.find(reason, "3 Boon", 1, true), "a fourth Boon is refused")
assert(Spec.canAdd(existing, "1:A@7", "Boon", 3, 9), "recasting the same spell on the same holder refreshes")
assert(Spec.canAdd(existing, "4:E@7", "Bane", 3, 9), "a second Bane fits")
assert(Spec.canAdd(existing, "4:E@7", "Neutral", 3, 9), "different types stack separately")
ok, reason = Spec.canAdd(existing, "4:E@7", "Neutral", 3, 4)
assert(not ok and string.find(reason, "4 enchantments", 1, true), "total cap")

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
