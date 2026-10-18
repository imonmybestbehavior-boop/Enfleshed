-- Run by scripts/run_luau_unit_tests.py (loadfile shim): SpellStatCaps requires CombatPolicy via script.Parent.
local Policy = assert(loadfile("src/shared/Modules/CombatPolicy.luau"))()
local Caps = assert(loadfile(
	"src/shared/Modules/SpellStatCaps.luau",
	"t",
	setmetatable({
		script = { Parent = { CombatPolicy = "policy" } },
		require = function()
			return Policy
		end,
	}, { __index = getfenv() })
))()
local Profiles = assert(loadfile("src/shared/Configuration/SpellStatCaps.luau"))()
local open, ranked = Profiles.PvPOpen, Profiles.PvPRanked
for _, profile in { open, ranked } do
	assert(profile.MaxAttributeChange and profile.MaxDamageTakenChange and profile.MaxResistanceChange)
	assert(profile.MaxResistanceChange <= 1, "resistance caps are fractions")
end
assert(
	ranked.MaxDamageTakenChange <= open.MaxDamageTakenChange and ranked.MaxResistanceChange <= open.MaxResistanceChange
)

-- Profile selection
local a = { UserId = 1, Zone = nil, DuelOpponent = nil }
local b = { UserId = 2, Zone = nil, DuelOpponent = nil }
assert(Caps.profileName(a, nil) == "PvE" and Caps.profileName(nil, b) == "PvE", "NPC hits are PvE")
assert(Caps.profileName(a, b) == "PvE", "co-op support between teammates is PvE")
assert(Caps.profileName(a, a) == "PvE", "self is PvE")
a.Zone, b.Zone = "Open", "Open"
assert(Caps.profileName(a, b) == "PvPOpen")
a.Zone, b.Zone = "Ranked", "Ranked"
assert(Caps.profileName(a, b) == "PvPRanked")
a.Zone, b.Zone = "Ranked", "Open"
assert(Caps.profileName(a, b) == "PvE", "different zones cannot fight, so no PvP profile")
a.Zone, b.Zone, a.DuelOpponent, b.DuelOpponent = nil, nil, 2, 1
assert(Caps.profileName(a, b) == "PvPOpen", "duels use the open profile")

-- PvE is identity and never copies
local payload = { Kind = "Slow", Multiplier = 0.1, Duration = 30 }
assert(Caps.payload(payload, Profiles.PvE, 1) == payload)
assert(Caps.payload(payload, nil, 1) == payload)

-- Effective values (as the executors compute them) never exceed caps
local function slowEffective(p, potency)
	return 1 - (1 - p.Multiplier) * potency
end
for _, potency in ipairs({ 0.5, 1, 2, 4 }) do
	local capped = Caps.payload(payload, open, potency)
	assert(slowEffective(capped, potency) >= open.MinSlowMultiplier - 1e-9, "slow floor at potency " .. potency)
	assert(capped.Duration == open.MaxEffectDuration, "duration capped")
	local dot = Caps.payload({ Kind = "DamageOverTime", Amount = 50, Duration = 10 }, ranked, potency)
	assert(dot.Amount * potency <= ranked.MaxDotPerTick + 1e-9, "dot per tick capped")
	local heal = Caps.payload({ Kind = "Heal", Amount = 100 }, open, potency)
	assert(heal.Amount * potency <= open.MaxHealPerHit + 1e-9, "heal capped")
	local disp = Caps.payload({ Kind = "Displacement", Distance = 24 }, open, potency)
	assert(disp.Distance * potency <= open.MaxDisplacement + 1e-9, "displacement capped")
	local grow = Caps.payload({ Kind = "Transformation", Multiplier = 1.35, Duration = 6 }, open, potency)
	assert(1 + (grow.Multiplier - 1) * potency <= open.MaxTransformScale + 1e-9, "growth capped")
	local shrink = Caps.payload({ Kind = "Transformation", Multiplier = 0.7, Duration = 6 }, open, potency)
	assert(1 + (shrink.Multiplier - 1) * potency >= open.MinTransformScale - 1e-9, "shrink capped")
	local debuff = Caps.payload({ Kind = "ModifyAttribute", Amount = -100, Duration = 8 }, open, potency)
	assert(math.abs(debuff.Amount * potency) <= open.MaxAttributeChange + 1e-9, "attribute change capped")
	-- DamageTaken and Resistance have their own PvP caps; other attributes use MaxAttributeChange.
	local vulnerable =
		Caps.payload({ Kind = "ModifyAttribute", Attribute = "DamageTaken", Amount = 50, Duration = 8 }, open, potency)
	assert(math.abs(vulnerable.Amount * potency - open.MaxDamageTakenChange) < 1e-9, "damage taken capped")
	local exposed = Caps.payload(
		{ Kind = "ModifyAttribute", Attribute = "Resistance", Element = "Fire", Amount = -1, Duration = 8 },
		open,
		potency
	)
	assert(math.abs(exposed.Amount * potency + open.MaxResistanceChange) < 1e-9, "resistance change capped")
	assert(exposed.Element == "Fire", "capping keeps the element")
	local slowCast =
		Caps.payload({ Kind = "ModifyAttribute", Attribute = "CastSpeed", Amount = -50, Duration = 8 }, open, potency)
	assert(
		math.abs(slowCast.Amount * potency + open.MaxAttributeChange) < 1e-9,
		"percent attributes use MaxAttributeChange"
	)
	local tinyResist = Caps.payload(
		{ Kind = "ModifyAttribute", Attribute = "Resistance", Element = "Ice", Amount = 0.05, Duration = 8 },
		open,
		potency
	)
	assert(tinyResist.Amount == 0.05, "values under the cap are untouched")
end
assert(Caps.payload({ Kind = "Bind", Duration = 4 }, ranked, 1).Duration == ranked.MaxBindDuration, "bind cap")
assert(Caps.payload({ Kind = "Force", Magnitude = 100, Upward = 90 }, open, 1).Magnitude == open.MaxForce, "force cap")
assert(Caps.payload({ Kind = "TimeDilation", Rate = 0.25, Duration = 9 }, open, 1).Rate == open.MinTimeRate)
assert(Caps.payload({ Kind = "TimeDilation", Rate = 1.5, Duration = 9 }, open, 1).Rate == 1.5, "haste is not a debuff")
assert(Caps.payload({ Kind = "Heal", Amount = 5 }, open, 1).Amount == 5, "values under the cap are unchanged")
local original = { Kind = "Heal", Amount = 100 }
Caps.payload(original, open, 1)
assert(original.Amount == 100, "input payload never mutated")

-- Damage
assert(Caps.damage(100, Profiles.PvE) == 100, "PvE damage unchanged")
assert(Caps.damage(20, open) == 20 * open.DamageMultiplier)
assert(Caps.damage(1000, ranked) == ranked.MaxDamagePerHit)

print("Spell stat caps: profile selection, PvE identity, potency-aware payload caps and damage caps passed")
