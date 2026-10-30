-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicCrowdControlSpec.luau"))()

-- Stun diminishing returns: full, then 50% within 8 s, then immune for 8 s.
local h = Spec.newHistory()
assert(Spec.applyStun(h, 0, 1.2) == 1.2, "first stun: full")
assert(Spec.applyStun(h, 3, 1.2) == 0.6, "second within 8 s: 50%")
assert(Spec.applyStun(h, 5, 1.2) == 0, "third within 8 s: not applied")
assert(Spec.applyStun(h, 9, 1.2) == 0, "immune for 8 s after the third")
assert(Spec.applyStun(h, 12.9, 1.2) == 0, "still immune just before 13 s")
assert(Spec.applyStun(h, 13, 1.2) == 1.2, "immunity over: a fresh window, full again")
assert(Spec.applyStun(h, 14, 1.2) == 0.6, "and diminishing again inside it")

local spaced = Spec.newHistory()
assert(Spec.applyStun(spaced, 0, 1) == 1)
assert(Spec.applyStun(spaced, 8.5, 1) == 1, "a stun after the 8 s window starts over at full")
assert(Spec.applyStun(spaced, 10, 1) == 0.5)

-- PvP: the cap (0.5 s) is applied to the authored duration before DR.
local pvp = Spec.newHistory()
assert(Spec.applyStun(pvp, 0, math.min(1.5, 0.5)) == 0.5)
assert(Spec.applyStun(pvp, 1, math.min(1.5, 0.5)) == 0.25)

-- Action gating.
local function blocked(category, stunned, silenced)
	return (Spec.blocks(category, stunned, silenced))
end
assert(blocked("Attack", true, false) and blocked("Move", true, false) and blocked("Cast", true, false))
assert(not blocked("Attack", false, true), "Silence leaves melee alone")
assert(not blocked("Move", false, true), "Silence leaves movement alone")
assert(blocked("Cast", false, true), "Silence blocks casting")
assert(not blocked("", true, true), "other actions (sprint, equip, commands) are never blocked")
local _, reason = Spec.blocks("Cast", true, true)
assert(reason == "Stunned", "Stun is reported first")
assert(Spec.ActionCategories.Light == "Attack" and Spec.ActionCategories.Dash == "Move")
assert(Spec.ActionCategories.MagicStart == "Cast" and Spec.ActionCategories.EquipmentUse == "Cast")
assert(Spec.ActionCategories.SummonCommand == nil, "summon orders stay available")

-- Cleanse: matching by polarity and element, longest-remaining first, then newest.
local candidates = {
	{ Id = "slowShort", Polarity = "Bane", Remaining = 1, AppliedAt = 5 },
	{ Id = "dotLong", Polarity = "Bane", Element = "Fire", Remaining = 6, AppliedAt = 1 },
	{ Id = "hexForever", Polarity = "Bane", Remaining = math.huge, AppliedAt = 0 },
	{ Id = "markFireNew", Polarity = "Bane", Element = "Fire", Remaining = 6, AppliedAt = 3 },
	{ Id = "shield", Polarity = "Boon", Remaining = 9, AppliedAt = 2 },
	{ Id = "reveal", Polarity = "Neutral", Remaining = 20, AppliedAt = 2 },
}
local function ids(list)
	local out = {}
	for _, c in ipairs(list) do
		table.insert(out, c.Id)
	end
	return table.concat(out, ",")
end
assert(
	ids(Spec.select(candidates, "Banes", 2)) == "hexForever,markFireNew",
	"unending first, then newest of equal time"
)
assert(ids(Spec.select(candidates, "Banes", 10)) == "hexForever,markFireNew,dotLong,slowShort")
assert(ids(Spec.select(candidates, "Banes", 5, "Fire")) == "markFireNew,dotLong", "element filter")
assert(ids(Spec.select(candidates, "Boons", 3)) == "shield", "Boons only")
assert(ids(Spec.select(candidates, "Everything", 3)) == "", "unknown filter removes nothing")
assert(#Spec.select({}, "Banes", 3) == 0)
assert(ids(Spec.cleanseOrder(candidates)):sub(1, 10) == "hexForever", "order does not mutate or filter")
assert(candidates[1].Id == "slowShort", "input untouched")
print("Magic crowd control spec: stun diminishing returns, action gating and cleanse ordering passed")
