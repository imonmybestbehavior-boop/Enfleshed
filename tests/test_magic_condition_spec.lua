local spec = assert(loadfile("src/shared/Modules/MagicConditionSpec.luau"))()
spec.configureSpecialResources({ Focus = { Capacity = 100 } })
assert(spec.validate({ Family = "Resource", Property = "Focus", Operator = "<", Value = 20 }))
assert(spec.validate({ Family = "Resource", Property = "FocusPercent", Operator = "<=", Value = 0.25 }))
assert(not spec.validate({ Family = "Resource", Property = "UnknownPool", Operator = "<", Value = 20 }))

local valid = {
	Operator = "ALL",
	Conditions = {
		{ Family = "Caster", Property = "IsAlive", Operator = "Is", Value = true },
		{
			Operator = "ANY",
			Conditions = {
				{ Family = "Target", Property = "HealthPercent", Operator = "<", Value = 0.5 },
				{ Family = "Relationship", Property = "IsHostile", Operator = "==", Value = true },
			},
		},
	},
}
assert(spec.validate(valid))
assert(spec.validate({ "OnGround", "HasLineOfSight" }))
assert(
	spec.validate({
		Family = "Status",
		Property = "TimeRate",
		Operator = "<",
		Value = 0.5,
	}),
	"Time-rate status should be available to spell conditions"
)
assert(
	spec.validate({ Family = "Environment", Property = "Zone", Operator = "==", Value = "Barracks" }),
	"server-registered environment zones should be available to spell conditions"
)
assert(
	not spec.validate({ Family = "Environment", Property = "MagicZonePart", Operator = "==", Value = "anything" }),
	"condition rules must not expose arbitrary environment properties"
)
assert(spec.validate({
	Operator = "ALL",
	Conditions = {
		{ Family = "Relationship", Property = "IsNeutral", Operator = "==", Value = true },
		{ Family = "SpellState", Property = "IsMaintained", Operator = "==", Value = true },
		{ Family = "Target", Property = "HasLineOfSight", Operator = "==", Value = true },
	},
}))
for _, property in ipairs({
	"DistanceFromCaster",
	"RemainingDuration",
	"PierceCount",
	"BounceCount",
	"AbsorbedEnergy",
	"ControlledMass",
	"HasCurrentTarget",
}) do
	local descriptor = spec.Properties.SpellState[property]
	local value = descriptor.Min
	local operator = ">="
	if descriptor.Kind == "Boolean" then
		value = true
		operator = "=="
	end
	assert(spec.validate({ Family = "SpellState", Property = property, Operator = operator, Value = value }))
end
assert(
	spec.validate({
		Operator = "ALL",
		Conditions = {
			{ Family = "Environment", Property = "ZoneTags", Operator = "Has", Value = "indoors" },
			{ Family = "Status", Property = "IsBound", Operator = "Is", Value = true },
			{ Family = "Status", Property = "IsRevealed", Operator = "==", Value = false },
			{ Family = "Status", Property = "MagicArmorBonus", Operator = ">", Value = 0 },
			{ Family = "Status", Property = "ElementalMarks", Operator = "Has", Value = "Fire" },
			{ Family = "Status", Property = "IsBurning", Operator = "==", Value = true },
			{ Family = "Status", Property = "IsWet", Operator = "==", Value = true },
			{ Family = "Status", Property = "MagicStrengthBonus", Operator = "<", Value = 0 },
		},
	}),
	"zone tags and exposed status values should be authorable"
)
assert(
	not spec.validate({ Family = "Status", Property = "ElementalMarks", Operator = "Has", Value = string.rep("x", 49) })
)
assert(spec.validate({ Family = "SpellState", Property = "Tags", Operator = "Has", Value = "summon" }))
assert(spec.validate({ Family = "Target", Property = "Tags", Operator = "Has", Value = "undead" }))
assert(not spec.validate({ Family = "Target", Property = "Tags", Operator = "Has", Value = string.rep("x", 25) }))
assert(not spec.validate({
	Family = "SpellState",
	Property = "Tags",
	Operator = "Has",
	Value = string.rep("x", 49),
}))
assert(not spec.validate({
	Family = "Environment",
	Property = "ZoneTags",
	Operator = "Has",
	Value = "this tag contains an invalidly long string",
}))
assert(
	spec.validateForFamilies(
		{ Family = "Caster", Property = "HealthPercent", Operator = "<=", Value = 0.25 },
		spec.EndConditionFamilies
	)
)
assert(
	spec.validateForFamilies(
		{ Family = "Status", Property = "HasShield", Operator = "==", Value = true },
		spec.EndConditionFamilies
	),
	"active effects should be able to end when the caster's shield state changes"
)
assert(
	not spec.validateForFamilies(
		{ Family = "Target", Property = "HealthPercent", Operator = "<=", Value = 0.25 },
		spec.EndConditionFamilies
	)
)

local function reject(tree)
	local ok = spec.validate(tree)
	assert(not ok, "invalid condition tree was accepted")
end

local bad = {
	Operator = "NOT",
	Conditions = {
		{ Family = "Target", Property = "HealthPercent", Operator = "<", Value = 2 },
	},
}
reject(bad)
bad = {
	Operator = "ALL",
	Conditions = {
		[1] = { Family = "Target", Property = "IsAlive", Operator = "==", Value = true },
		[3] = { Family = "Target", Property = "IsPlayer", Operator = "==", Value = false },
	},
}
reject(bad)
bad = {
	Operator = "ANY",
	Conditions = {
		{ Family = "Target", Property = "Parent.Script", Operator = "==", Value = "unsafe" },
	},
}
reject(bad)
bad = {
	Operator = "NOT",
	Conditions = {
		{ Family = "Target", Property = "IsPlayer", Operator = "==", Value = false },
		{ Family = "Target", Property = "IsAlive", Operator = "==", Value = true },
	},
}
reject(bad)
bad = {
	Operator = "ALL",
	Conditions = {
		{ Family = "Target", Property = "HealthPercent", Operator = "Execute", Value = 0.5 },
	},
}
reject(bad)

print("Magic condition spec: nested trees, legacy conditions, allowlists, and limits passed")
