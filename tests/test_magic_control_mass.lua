local mass = assert(loadfile("src/shared/Modules/MagicControlMassSpec.luau"))()

assert(mass.allows(75, 500), "ordinary humanoid assemblies should fit a typical authored control limit")
assert(not mass.allows(600, 500), "assemblies above an authored control limit must be rejected")
assert(not mass.allows(0, 500), "zero-mass assemblies are not controllable")
assert(not mass.allows(math.huge, 500), "non-finite assembly mass must be rejected")
assert(not mass.allows(75, math.huge), "non-finite authored limits must be rejected")

local totals = {}
local caster, otherCaster = {}, {}
assert(mass.adjust(totals, caster, "SpellA", 75) == 75)
assert(mass.adjust(totals, caster, "SpellA", 125) == 200)
assert(mass.adjust(totals, caster, "SpellB", 50) == 50)
assert(mass.adjust(totals, otherCaster, "SpellA", 400) == 400)
assert(mass.total(totals, caster, "SpellA") == 200, "mass must aggregate by caster and spell")
mass.adjust(totals, caster, "SpellA", -75)
assert(mass.total(totals, caster, "SpellA") == 125, "removing one controlled target should update the total")
mass.adjust(totals, caster, "SpellA", -1000)
assert(mass.total(totals, caster, "SpellA") == 0, "controlled mass should not become negative")
assert(mass.total(totals, caster, "SpellB") == 50, "removing one spell total must retain other spells")
assert(mass.total(totals, otherCaster, "SpellA") == 400, "caster totals must stay isolated")

print("Magic control mass: finite server-side bounds passed")
