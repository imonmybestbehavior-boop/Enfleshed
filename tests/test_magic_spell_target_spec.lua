-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicSpellTargetSpec.luau"))()
local Dispel = assert(loadfile("src/shared/Modules/MagicDispelSpec.luau"))()
local Lens = assert(loadfile("src/shared/Modules/MagicSpellLensSpec.luau"))()

local function p(x, y, z)
	return { X = x, Y = y, Z = z }
end

-- Relationship filter (default Hostile).
assert(Spec.relationshipAllowed(nil, "Hostile") and not Spec.relationshipAllowed(nil, "Allied"))
assert(Spec.relationshipAllowed("Allied", "Self") and not Spec.relationshipAllowed("Allied", "Hostile"))
assert(Spec.relationshipAllowed("Any", "Neutral"))

-- Hit tests.
assert(Spec.areaHit(p(5, 0, 0), p(0, 0, 0), 6, 0) and not Spec.areaHit(p(9, 0, 0), p(0, 0, 0), 6, 0))
assert(Spec.areaHit(p(9, 0, 0), p(0, 0, 0), 6, 4), "an Explode radius reaches further")
assert(Spec.boundsHit(p(2, 0, 0), p(0, 0, 0), 3, 0))
assert(Spec.tetherHit(p(5, 0.8, 0), p(0, 0, 0), p(10, 0, 0), 2, 0), "within 1 stud of the line")
assert(not Spec.tetherHit(p(5, 2, 0), p(0, 0, 0), p(10, 0, 0), 2, 0))
assert(not Spec.tetherHit(p(12, 0, 0), p(0, 0, 0), p(10, 0, 0), 2, 0), "past the end")

-- Force distance and once-per-cast.
assert(Spec.forceDistance(8, nil, 10) == 8 and Spec.forceDistance(20, nil, 10) == 10)
assert(Spec.forceDistance(8, 6, 10) == 6, "PvP cap")
assert(Spec.pushTravel(10, nil, 1, 0.5) == 10 and Spec.pushTravel(10, 4, 1, 0.5) == 3, "stops 1 stud short of a wall")
assert(Spec.pushTravel(10, 1.2, 1, 0.5) == 0, "a wall right there: no move")
local spellKinds = { Dispel = true, Force = true }
assert(Spec.stepMode({ Payloads = { { Kind = "Dispel" } } }, spellKinds) == "Required")
assert(Spec.stepMode({ Behavior = "Explode", Payloads = { { Kind = "Force" } } }, spellKinds) == "Optional")
assert(Spec.stepMode({ Payloads = { { Kind = "Force" }, { Kind = "Damage" } } }, spellKinds) == nil, "mixed payloads")
assert(Spec.stepMode({ Behavior = "Beam", Payloads = { { Kind = "Force" } } }, spellKinds) == nil, "only Explode")
assert(Spec.stepMode({ Condition = {}, Payloads = { { Kind = "Force" } } }, spellKinds) == nil, "no conditions")
assert(Spec.stepMode({ Payloads = {} }, spellKinds) == nil)
local synced = { Payloads = { { Kind = "Dispel" } } }
Spec.syncStep(synced, spellKinds)
assert(synced.TargetKind == "Spell", "a Dispel step targets spells")
synced.Payloads[1] = { Kind = "Force" }
synced.SpellRelationship = "Any"
Spec.syncStep(synced, spellKinds)
assert(synced.TargetKind == "Spell" and synced.SpellRelationship == "Any", "Force keeps the author's choice")
synced.Payloads[1] = { Kind = "Damage" }
Spec.syncStep(synced, spellKinds)
assert(synced.TargetKind == nil and synced.SpellRelationship == nil, "a creature-only step is cleared")
local touched, field = {}, {}
assert(Spec.claim(touched, field) and not Spec.claim(touched, field), "once per spell per cast")

-- Dispel.
assert(Dispel.resolve("End", nil, 8, 10, 20) == "End", "cheap target: ended")
local action, remaining = Dispel.resolve("End", nil, 8, 30, 20)
assert(action == "Shorten" and remaining == 4, "expensive target: halved")
assert(Dispel.resolve("End", nil, nil, 30, 20) == "None", "expensive untimed target: untouched")
assert(Dispel.resolve("End", nil, nil, 10, 20) == "End", "cheap untimed target: ended")
action, remaining = Dispel.resolve("Shorten", 5, 8, 99, 1)
assert(action == "Shorten" and remaining == 3, "Shorten ignores complexity")
assert(Dispel.resolve("Shorten", 5, nil, 1, 99) == "None", "untimed spells cannot be shortened")
assert(Dispel.persistentAllowed(7, 7) and not Dispel.persistentAllowed(8, 7) and not Dispel.persistentAllowed(nil, 7))
assert(
	Dispel.polarity(nil) == "Bane" and Dispel.polarity("Allied") == "Neutral" and Dispel.polarity("Any") == "Neutral"
)

-- Lens: once per field, PvP floors.
local projectile = {}
local fieldA, fieldB = {}, {}
local change = Lens.apply(projectile, fieldA, { Slow = 0.4, AddMark = "Fire" }, nil)
assert(change.Speed == 0.4 and change.Potency == 1 and change.Mark == "Fire")
assert(Lens.apply(projectile, fieldA, { Slow = 0.4 }, nil) == nil, "once per field")
assert(Lens.apply(projectile, fieldB, { Slow = 0.4 }, nil) ~= nil, "another field may change it")
change = Lens.apply({}, fieldA, { Slow = 0.3, ScalePotency = 0.5 }, { Potency = 0.7, Slow = 0.6 })
assert(change.Speed == 0.6 and change.Potency == 0.7, "PvP floors on a hostile player's projectile")
assert(Lens.hasModifier({ AddMark = "Water" }) and not Lens.hasModifier({}))
print("Magic spell target spec: relationship, hit tests, force, once per cast, dispel rules and lenses passed")
