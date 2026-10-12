local evaluator = assert(loadfile("src/shared/Modules/MagicConditionEvaluator.luau"))()

local state = {
	Caster = { IsAlive = true, HealthPercent = 0.75 },
	Target = { HealthPercent = 0.3, IsPlayer = false, HasLineOfSight = true, Tags = "|enfleshed|armored|" },
	Relationship = { IsHostile = true, IsAlly = false, IsNeutral = false },
	SpellState = { IsMaintained = true, ControlledMass = 180, Tags = "|summon|support|" },
	Status = {
		TimeRate = 0.4,
		IsBound = true,
		IsRevealed = false,
		MagicArmorBonus = 25,
		MagicStrengthBonus = -20,
		ElementalMarks = "|fire|water|",
		IsBurning = true,
		IsWet = true,
	},
	Environment = { Zone = "Barracks", ZoneTags = "|military|indoors|" },
}
local function resolve(family, property)
	return state[family] and state[family][property]
end

local tree = {
	Operator = "ALL",
	Conditions = {
		{ Family = "Caster", Property = "IsAlive", Operator = "Is", Value = true },
		{
			Operator = "ANY",
			Conditions = {
				{ Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 },
				{ Family = "Relationship", Property = "IsAlly", Operator = "==", Value = true },
			},
		},
	},
}
assert(evaluator.evaluate(tree, resolve) == true, "nested ALL/ANY did not pass")

tree.Conditions[2].Operator = "NOT"
tree.Conditions[2].Conditions = {
	{ Family = "Target", Property = "IsPlayer", Operator = "==", Value = true },
}
assert(evaluator.evaluate(tree, resolve) == true, "NOT did not invert its child")

tree.Operator = "ANY"
tree.Conditions = {
	{ Family = "Caster", Property = "HealthPercent", Operator = ">=", Value = 0.8 },
	{ Family = "Relationship", Property = "IsHostile", Operator = "==", Value = true },
}
assert(evaluator.evaluate(tree, resolve) == true, "ANY did not accept one matching rule")
assert(
	evaluator.evaluate({ Family = "Relationship", Property = "IsNeutral", Operator = "==", Value = false }, resolve)
		== true,
	"Relationship neutrality must be available to condition rules"
)
assert(
	evaluator.evaluate({ Family = "SpellState", Property = "IsMaintained", Operator = "==", Value = true }, resolve)
		== true,
	"maintained-state conditions should evaluate during active channels"
)
assert(
	evaluator.evaluate({ Family = "SpellState", Property = "ControlledMass", Operator = ">=", Value = 150 }, resolve)
		== true,
	"controlled assembly mass should be available to runtime conditions"
)
assert(
	evaluator.evaluate({ Family = "SpellState", Property = "Tags", Operator = "Has", Value = "summon" }, resolve)
		== true
)
assert(
	evaluator.evaluate({ Family = "SpellState", Property = "Tags", Operator = "Has", Value = "sum" }, resolve) == false
)
assert(evaluator.evaluate({ Family = "Target", Property = "Tags", Operator = "Has", Value = "enfleshed" }, resolve))
assert(
	evaluator.evaluate({ Family = "Target", Property = "Tags", Operator = "DoesNotHave", Value = "undead" }, resolve)
)
assert(
	not evaluator.evaluate({ Family = "Target", Property = "Tags", Operator = "Has", Value = "flesh" }, resolve),
	"target tag rules should use exact authored tokens"
)
assert(
	evaluator.evaluate({ Family = "Status", Property = "TimeRate", Operator = "<", Value = 0.5 }, resolve) == true,
	"Time-rate status should be usable in target conditions"
)
assert(
	evaluator.evaluate({ Family = "Target", Property = "HasLineOfSight", Operator = "==", Value = true }, resolve)
		== true,
	"target visibility should be available to composable conditions"
)
assert(
	evaluator.evaluate({ Family = "Environment", Property = "Zone", Operator = "==", Value = "Barracks" }, resolve)
		== true,
	"named environment zones should be compared through the ordinary condition evaluator"
)
assert(
	evaluator.evaluate({ Family = "Environment", Property = "ZoneTags", Operator = "Has", Value = "indoors" }, resolve)
		== true,
	"environment tags should support exact token matching"
)
assert(
	evaluator.evaluate({ Family = "Environment", Property = "ZoneTags", Operator = "Has", Value = "door" }, resolve)
		== false,
	"environment tag matching must not accept partial words"
)
assert(
	evaluator.evaluate(
		{ Family = "Environment", Property = "ZoneTags", Operator = "DoesNotHave", Value = "market" },
		resolve
	) == true,
	"missing environment tags should support negative requirements"
)
assert(evaluator.evaluate({ Family = "Status", Property = "IsBound", Operator = "Is", Value = true }, resolve))
assert(evaluator.evaluate({ Family = "Status", Property = "IsRevealed", Operator = "==", Value = false }, resolve))
assert(evaluator.evaluate({ Family = "Status", Property = "MagicArmorBonus", Operator = ">", Value = 10 }, resolve))
assert(evaluator.evaluate({ Family = "Status", Property = "MagicStrengthBonus", Operator = "<", Value = 0 }, resolve))
assert(evaluator.evaluate({ Family = "Status", Property = "IsBurning", Operator = "==", Value = true }, resolve))
assert(evaluator.evaluate({ Family = "Status", Property = "IsWet", Operator = "==", Value = true }, resolve))
assert(
	evaluator.evaluate({ Family = "Status", Property = "ElementalMarks", Operator = "Has", Value = "Fire" }, resolve)
)
assert(
	evaluator.evaluate(
		{ Family = "Status", Property = "ElementalMarks", Operator = "DoesNotHave", Value = "Ice" },
		resolve
	)
)
assert(
	not evaluator.evaluate({ Family = "Status", Property = "ElementalMarks", Operator = "Has", Value = "Fir" }, resolve),
	"Elemental mark conditions should match exact element names"
)
state.Environment.Zone = ""
assert(
	evaluator.evaluate({ Family = "Environment", Property = "Zone", Operator = "!=", Value = "Barracks" }, resolve)
		== true,
	"a caster outside all tagged zones should compare as an empty zone ID"
)

local zoneSpec = assert(loadfile("src/shared/Modules/MagicEnvironmentZoneSpec.luau"))()
assert(zoneSpec.encodeTags("Market, indoors; MARKET | upper") == "|market|indoors|upper|")
assert(zoneSpec.encodeTags("a!! b c") == "|b|c|", "invalid tag symbols should be ignored")
assert(zoneSpec.hasTag("|market|indoors|", "market"))
assert(not zoneSpec.hasTag("|market|indoors|", "mar"))

local castOnly = {
	Operator = "ALL",
	Conditions = {
		{ Family = "Caster", Property = "IsAlive", Operator = "==", Value = false },
		{ Family = "Target", Property = "IsPlayer", Operator = "==", Value = true },
	},
}
local castResult = evaluator.evaluate(castOnly, resolve, { Caster = true })
assert(castResult == false, "ALL ignored a failing applicable cast rule")

local targetOnly = {
	Operator = "ANY",
	Conditions = {
		{ Family = "Target", Property = "IsPlayer", Operator = "==", Value = true },
	},
}
assert(
	evaluator.evaluate(targetOnly, resolve, { Caster = true }) == nil,
	"phase-local evaluation should defer target rules"
)

assert(evaluator.evaluate({ Family = "Target", Property = "Name", Operator = "Has", Value = "test" }, function()
	return "TrainingTestDummy"
end) == true)

local endWhen = {
	Operator = "ANY",
	Conditions = {
		{ Family = "Caster", Property = "HealthPercent", Operator = "<=", Value = 0.25 },
		{ Family = "Resource", Property = "Mana", Operator = "<=", Value = 0 },
		{ Family = "Target", Property = "IsAlive", Operator = "==", Value = false },
	},
}
local endValues = {
	Caster = { HealthPercent = 0.4 },
	Resource = { Mana = 0 },
}
assert(
	evaluator.evaluate(endWhen, function(family, property)
		return endValues[family] and endValues[family][property]
	end, { Caster = true, Resource = true, SpellState = true, Environment = true, Time = true }) == true,
	"end conditions should resolve caster/resource rules and ignore target-only leaves"
)

print("Magic condition evaluator: nested logic, comparisons, and phase-safe rules passed")
