-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicHealSpec.luau"))()

-- Modes.
assert(Spec.base(nil, 20, 150, 40) == 20, "default is Flat")
assert(Spec.base("Flat", 20, 150, 40) == 20)
assert(Spec.base("PercentMaxHealth", 10, 150, 40) == 15, "10% of 150 max health")
assert(Spec.base("PercentDamageDealt", 50, 150, 40) == 20, "50% of 40 damage dealt (lifesteal)")
assert(Spec.base("PercentDamageDealt", 50, 150, nil) == 0, "no damage information: nothing")
assert(Spec.base("PercentMaxHealth", 10, 0 / 0, 40) == 0, "NaN max health: nothing")
assert(Spec.base("Flat", -5, 150, 40) == 0, "never negative")

-- Overflow: what the heal could not restore becomes a shield, within the limit.
assert(Spec.overflow(30, 10, nil) == 20, "20 overflow when only 10 was missing")
assert(Spec.overflow(30, 30, nil) == 0, "no overflow when all of it healed")
assert(Spec.overflow(30, 10, 25) == 15, "the per-hit cap applies before overflow")
assert(Spec.overflow(30, 40, nil) == 0, "never negative")
print("Magic heal spec: flat / percent max health / percent damage dealt and overflow passed")
