local spec = assert(loadfile("src/shared/Modules/MagicSpecialResourceSpec.luau"))()
local definitions = {
	Focus = { Label = "Focus", Capacity = 100, Starting = 80, RecoveryPerSecond = 5, Attribute = "MagicFocus" },
	Soul = { Label = "Soul", Capacity = 50, Starting = 30, RecoveryPerSecond = 0, Attribute = "MagicSoul" },
}

assert(spec.validateDefinitions(definitions), "registered resource definitions should validate")
local current = spec.defaults(definitions)
assert(current.Focus == 80 and current.Soul == 30)
assert(spec.validateCurrent(current, definitions))
assert(spec.validateCosts({ Focus = 20, Soul = 10 }, definitions, 2, 100))
assert(not spec.validateCosts({ Unknown = 1 }, definitions, 2, 100), "unregistered resource ids must fail")
assert(not spec.validateCosts({ Focus = 101 }, definitions, 2, 100), "resource costs must remain bounded")
assert(not spec.validateCosts({ Focus = 1, Soul = 1 }, definitions, 1, 100), "resource cost count must remain bounded")

local affordable = spec.canAfford(current, { Focus = 20, Soul = 30 }, definitions)
assert(affordable, "a spell should pass when all named resources are available")
local spent = spec.spend(current, { Focus = 20, Soul = 30 }, definitions)
assert(spent and current.Focus == 60 and current.Soul == 0)
local rejected = spec.spend(current, { Focus = 1, Soul = 1 }, definitions)
assert(not rejected and current.Focus == 60 and current.Soul == 0, "failed multi-pool spend must be atomic")
assert(spec.advance(current, definitions, 2), "configured resources should recover independently")
assert(current.Focus == 70 and current.Soul == 0)
assert(not spec.validateCurrent({ Focus = math.huge, Soul = 0 }, definitions))

-- Phase 8: DrainResource / RestoreResource amounts.
local target, caster, taken = spec.drain(30, 50, 100, 20)
assert(target == 10 and caster == 70 and taken == 20, "drain moves the amount")
target, caster, taken = spec.drain(5, 50, 100, 20)
assert(target == 0 and caster == 55 and taken == 5, "never takes more than the target has")
target, caster, taken = spec.drain(30, 95, 100, 20)
assert(target == 10 and caster == 100 and taken == 20, "the target still loses it; the caster's excess is lost")
target, caster, taken = spec.drain(30, 50, 100, 0 / 0)
assert(target == 30 and caster == 50 and taken == 0, "NaN moves nothing")
local after, added = spec.restore(40, 100, 25)
assert(after == 65 and added == 25)
after, added = spec.restore(90, 100, 25)
assert(after == 100 and added == 10, "restore stops at capacity")
after, added = spec.restore(40, 100, -5)
assert(after == 40 and added == 0, "never negative")
print("Magic special resources: registry, bounds, atomic spend, recovery, and persistence values passed")
