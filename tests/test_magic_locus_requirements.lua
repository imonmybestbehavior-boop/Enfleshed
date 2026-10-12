local spec = assert(loadfile("src/shared/Modules/MagicLocusRequirementSpec.luau"))()

local requirements = {
	Capacity = 400,
	Efficiency = 1.2,
	Potency = 1.5,
	StrainTolerance = 35,
	ComplexityCapacity = 10,
}
assert(spec.validate(requirements))
local passes, reason = spec.check(requirements, {
	Capacity = 500,
	Efficiency = 1.25,
	Potency = 2,
	StrainTolerance = 40,
	ComplexityCapacity = 12,
})
assert(passes and reason == nil)
local fails, failureReason = spec.check(requirements, {
	Capacity = 300,
	Efficiency = 1.25,
	Potency = 2,
	StrainTolerance = 40,
	ComplexityCapacity = 12,
})
assert(not fails and failureReason == "Requires Locus Capacity ≥ 400")
assert(spec.check({}, { Capacity = 0, Efficiency = 1, Potency = 1, StrainTolerance = 0, ComplexityCapacity = 0 }))
assert(not spec.validate({ Unknown = 1 }))
assert(not spec.validate({ Capacity = -1 }))
assert(not spec.validate({ Potency = math.huge }))
assert(not spec.check(requirements, nil))

print("Magic Locus requirements: authoring bounds and server metric comparisons passed")
