-- Run from the repository root with: lua tests/test_magic_locus_model.lua
local model = assert(loadfile("src/shared/Modules/MagicLocusModel.luau", "t", {
	math = math,
}))()

local profile = {
	Capacity = 120,
	Efficiency = 2,
	Potency = 1.5,
	StrainTolerance = 60,
	ComplexityCapacity = 5,
}
local state = model.newState(profile, 500)
assert(state.Mana == 120, "Starting mana must be capped by Locus capacity")
assert(state.Potency == 1.5 and state.Efficiency == 2)

local mana, strain, complexity = model.cost({ ManaDemand = 20, Strain = 10, Complexity = 3 }, 0.5, 0.4, state)
assert(mana == 12 and strain == 6 and complexity == 3, "Efficiency, strain tolerance, and charge must scale costs")

local safety = { SafeManaDemand = 35, SafeStrain = 18 }
local result = model.evaluate(state, mana, strain, complexity, safety)
assert(result == "VALID", "A resource-safe cast should be valid")
result = model.evaluate(state, 121, strain, complexity, safety)
assert(result == "IMPOSSIBLE", "A cast beyond current mana must be impossible")
result = model.evaluate(state, mana, strain, 6, safety)
assert(result == "IMPOSSIBLE", "A cast beyond complexity capacity must be impossible")
result = model.evaluate(state, 40, strain, complexity, safety)
assert(result == "UNSAFE", "A cast beyond the safe demand threshold remains possible but unsafe")

state.Strain = 58
local reason, overextension
result, reason, overextension = model.evaluate(state, mana, strain, complexity, safety)
assert(result == "UNSAFE" and overextension, "Strain beyond tolerance must be reported as overextension risk")
assert(reason:find("overextension", 1, true), "Unsafe resource feedback must explain overextension")
model.spend(state, 10, strain)
assert(state.Mana == 110 and state.Strain == 64)
model.advance(state, 2, 10, 4)
assert(state.Mana == 120 and state.Strain == 56, "Recovery must clamp mana and restore strain")

local upkeepState = model.newState(profile, 20)
assert(model.upkeep(upkeepState, 20, 4, 1), "Ongoing resources should be paid while capacity remains")
assert(upkeepState.Mana == 10 and upkeepState.Strain == 2, "Ongoing use must respect Efficiency and StrainTolerance")
upkeepState.Mana = 5
assert(not model.upkeep(upkeepState, 20, 4, 1), "An active spell must terminate when it cannot pay upkeep")
assert(upkeepState.Mana == 0 and upkeepState.Strain == 3, "Final partial upkeep must scale its strain burden")

print("PASS: canonical Locus resource math, safety, overextension, recovery, and ongoing upkeep")
