local source = assert(loadstring(__MAGIC_ACTION_FLOW_SOURCE))
local Flow = source()

local schema = {
	EventOrder = { "OnCast", "OnImpact" },
	EventLabels = { OnCast = "When cast", OnImpact = "When this hits something" },
	Payloads = {
		Damage = { Label = "Damage the target" },
		Force = { Label = "Push or pull" },
	},
	Behaviors = { Explode = { Label = "Affect a nearby area" } },
}

local spell = {
	Triggers = {
		OnImpact = {
			{ Payloads = { { Kind = "Damage" } } },
			{ Behavior = "Explode", Payloads = { { Kind = "Force" } }, Condition = { Operator = "ALL" } },
		},
	},
}

local blocks = Flow.build(spell, schema)
assert(#blocks == 2, "Every authored step should remain visible")
assert(blocks[1].Relation == "WHEN" and blocks[1].Title == "Damage the target")
assert(blocks[2].Relation == "ALSO", "Independent steps at one event are simultaneous")
assert(blocks[2].Title == "Push or pull + Affect a nearby area")
assert(blocks[2].HasCondition and string.sub(blocks[2].ConditionLabel, 1, 3) == "IF ")
assert(Flow.canAddStep(spell, "OnImpact", 4))
local allowed, reason = Flow.canAddStep(spell, "OnImpact", 2)
assert(not allowed and string.find(reason, "limit", 1, true))

-- Readable condition summaries for the action map.
local low = { Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 }
local crowd = { Family = "SpellState", Property = "AreaOccupants", Operator = ">=", Value = 3 }
assert(Flow.conditionSummary({ Operator = "ALL", Conditions = { low } }) == "Target HealthPercent < 0.5")
assert(
	Flow.conditionSummary({ Operator = "ANY", Conditions = { low, { Operator = "ALL", Conditions = { crowd } } } })
		== "Target HealthPercent < 0.5 or (SpellState AreaOccupants ≥ 3)"
)
assert(Flow.conditionSummary({ Operator = "NOT", Conditions = { low } }) == "not (Target HealthPercent < 0.5)")
assert(
	Flow.describeStep("OnImpact", 1, { Payloads = {}, Condition = { Operator = "ALL", Conditions = { low } } }, schema).ConditionLabel
		== "IF Target HealthPercent < 0.5"
)

-- Branch helpers: a starter IF condition and its exact OTHERWISE inverse.
local branch = Flow.branchCondition()
assert(branch.Operator == "ALL" and branch.Conditions[1].Property == "HealthPercent")
local otherwise = assert(Flow.otherwise(branch, 4))
assert(otherwise.Operator == "NOT" and otherwise.Conditions[1].Operator == "ALL")
otherwise.Conditions[1].Conditions[1].Value = 0.9
assert(branch.Conditions[1].Value == 0.5, "Otherwise must copy, not alias, the original condition")
local back =
	assert(Flow.otherwise({ Operator = "NOT", Conditions = { { Operator = "ALL", Conditions = { low } } } }, 4))
assert(back.Operator == "ALL", "Inverting a NOT unwraps it instead of stacking NOT(NOT(...))")
local bare = assert(Flow.otherwise({ Operator = "NOT", Conditions = { low } }, 4))
assert(bare.Operator == "ALL" and bare.Conditions[1].Property == "HealthPercent", "A bare unwrapped rule is regrouped")
local deep = {
	Operator = "ALL",
	Conditions = { { Operator = "ALL", Conditions = { { Operator = "ALL", Conditions = { low } } } } },
}
local refused, refusedReason = Flow.otherwise(deep, 4)
assert(refused == nil and string.find(refusedReason, "nested", 1, true), "Inversion respects the depth limit")
assert(Flow.otherwise(nil, 4) == nil, "Unconditional steps have no otherwise")
local hurt = Flow.casterHealthBelow(50)
assert(hurt.Operator == "ALL" and hurt.Conditions[1].Family == "Caster", "stronger when hurt: a caster rule")
assert(hurt.Conditions[1].Property == "HealthPercent" and hurt.Conditions[1].Value == 0.5)
assert(Flow.casterHealthBelow(150).Conditions[1].Value == 0.99, "kept inside 1-99%")
print("PASS: action-flow adapter preserves steps, parallel semantics, and conditions; branch helpers")
