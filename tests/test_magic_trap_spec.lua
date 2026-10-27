-- Run by scripts/run_luau_unit_tests.py (loadfile shim).
local Spec = assert(loadfile("src/shared/Modules/MagicTrapSpec.luau"))()

-- Arm delay.
assert(Spec.armDelay(nil, false, nil) == 0)
assert(Spec.armDelay(2, false, 1.5) == 2, "PvP minimum applies to Hidden traps only")
assert(Spec.armDelay(0.5, true, 1.5) == 1.5, "Hidden trap in PvP: at least the minimum")
assert(Spec.armDelay(3, true, 1.5) == 3)
assert(Spec.armDelay(0 / 0, false, nil) == 0, "NaN")
assert(not Spec.armed(0.9, 1) and Spec.armed(1, 1))

-- Consume on trigger.
assert(Spec.consumes(true, 1) and not Spec.consumes(true, 0) and not Spec.consumes(false, 3))

-- Hidden marker viewers.
assert(Spec.canSee(1, 1, true), "the caster always sees their trap")
assert(Spec.canSee(2, 1, false), "allies and players outside PvP see it")
assert(not Spec.canSee(2, 1, true), "opponents never receive it")
local show, hide = Spec.diffViewers({ a = true, b = true }, { "b", "c" })
assert(#show == 1 and show[1] == "c" and #hide == 1 and hide[1] == "a")
show, hide = Spec.diffViewers({}, {})
assert(#show == 0 and #hide == 0)
print("Magic trap spec: arm delay, consume on trigger and hidden-marker viewers passed")
