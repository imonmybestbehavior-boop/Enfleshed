-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicConstructHealthSpec.luau"))()

-- Maximum health.
assert(Spec.maxHealth(nil, nil, 500) == nil, "no Health: indestructible")
assert(Spec.maxHealth(0, nil, 500) == nil)
assert(Spec.maxHealth(200, nil, 500) == 200)
assert(Spec.maxHealth(900, nil, 500) == 500, "hard limit")
assert(Spec.maxHealth(200, 150, 500) == 150, "PvP cap")

-- Who may damage it.
assert(Spec.canDamage(nil, 1, false), "NPC spells always")
assert(not Spec.canDamage(1, 1, true), "never its owner")
assert(Spec.canDamage(2, 1, true) and not Spec.canDamage(2, 1, false), "players only when they may fight the owner")

-- Damage.
local health, taken, destroyed = Spec.apply(50, 20)
assert(health == 30 and taken == 20 and not destroyed)
health, taken, destroyed = Spec.apply(30, 99)
assert(health == 0 and taken == 30 and destroyed, "overkill stops at zero")
health, taken = Spec.apply(30, -5)
assert(health == 30 and taken == 0, "negative damage ignored")
health, taken = Spec.apply(30, 0 / 0)
assert(health == 30 and taken == 0, "NaN ignored")

-- Restore.
assert(Spec.restore(nil, 100) == 100 and Spec.restore(40, 100) == 40 and Spec.restore(400, 100) == 100)
assert(Spec.restore(0, 100) == 1, "a saved Construct never restores destroyed")
print("Magic construct health spec: max health, damage rights, damage and restore passed")
