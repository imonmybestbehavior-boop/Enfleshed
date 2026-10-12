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

print("Magic special resources: registry, bounds, atomic spend, recovery, and persistence values passed")
