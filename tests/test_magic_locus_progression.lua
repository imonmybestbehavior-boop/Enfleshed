--!strict
local Spec = assert(loadfile("src/shared/Modules/MagicLocusProgressionSpec.luau"))()
local LocusModel = assert(loadfile("src/shared/Modules/MagicLocusModel.luau"))()
local specialResourceSpec = assert(loadfile("src/shared/Modules/MagicSpecialResourceSpec.luau"))()
local profileEnvironment = setmetatable({
	script = { Parent = { MagicSpecialResourceSpec = "specialResourceSpec" } },
	require = function(reference)
		assert(reference == "specialResourceSpec")
		return specialResourceSpec
	end,
}, { __index = _G })
local LocusProfile = assert(loadfile("src/shared/Modules/MagicLocusProfile.luau", "t", profileEnvironment))()

local base = {
	Capacity = 300,
	Efficiency = 1,
	Potency = 1,
	StrainTolerance = 30,
	ComplexityCapacity = 8,
}
local config = {
	Enabled = true,
	PracticeCastsPerRank = 25,
	MaximumRank = 12,
	PerRank = {
		Capacity = 15,
		Efficiency = 0.015,
		Potency = 0.015,
		StrainTolerance = 1.5,
		ComplexityCapacity = 0.25,
	},
}

local start = Spec.profile(base, config, 0)
assert(start.Rank == 0 and start.Progress == 0 and start.CastsToNextRank == 25)
assert(start.Metrics.Capacity == 300 and start.Metrics.Efficiency == 1)

local near = Spec.profile(base, config, 24)
assert(near.Rank == 0 and near.Progress == 24 / 25 and near.CastsToNextRank == 1)

local firstRank = Spec.profile(base, config, 25)
assert(firstRank.Rank == 1 and firstRank.Progress == 0 and firstRank.CastsToNextRank == 25)
assert(firstRank.Metrics.Capacity == 315)
assert(math.abs(firstRank.Metrics.Efficiency - 1.015) < 1e-9)
assert(math.abs(firstRank.Metrics.Potency - 1.015) < 1e-9)
assert(firstRank.Metrics.StrainTolerance == 31.5)
assert(firstRank.Metrics.ComplexityCapacity == 8.25)
local rankedState = LocusModel.newState(firstRank.Metrics, 300)
local manaDemand, strain = LocusModel.cost({ ManaDemand = 10, Strain = 10, Complexity = 2 }, 0, 0, rankedState)
assert(rankedState.Capacity == 315 and rankedState.Mana == 300)
assert(math.abs(manaDemand - 10 / 1.015) < 1e-9, "Ranked Efficiency should modify server mana calculation")
assert(math.abs(strain - 300 / 31.5) < 1e-9, "Ranked StrainTolerance should modify server strain calculation")

local capped = Spec.profile(base, config, 10000)
assert(capped.Rank == 12 and capped.CastsToNextRank == nil and capped.Progress == 1)
local maximum = Spec.maximumProfile(base, config)
assert(maximum.Capacity == 480 and maximum.ComplexityCapacity == 11)
local saved, savedIsSafe = LocusProfile.decode({ Version = 1, Mana = 400, Strain = 10 }, 300, maximum.Capacity, 1000)
assert(
	savedIsSafe and saved.Mana == 400,
	"Advanced Locus Mana must survive loading against the bounded maximum Capacity"
)

local disabled = Spec.profile(base, { Enabled = false }, 10000)
assert(disabled.Rank == 0 and disabled.Metrics.Capacity == base.Capacity)
local sandboxLocus = assert(loadfile("src/shared/Configuration/MagicLocus.luau"))()
local sandboxProfile = Spec.profile(base, sandboxLocus.Progression, 100000)
assert(
	sandboxProfile.Rank == 0 and sandboxProfile.Metrics.Potency == base.Potency,
	"The actual test-place config must keep Locus stats fixed regardless of casts"
)
local invalid = Spec.profile(base, config, 0 / 0)
assert(invalid.Rank == 0 and invalid.Metrics.Capacity == base.Capacity)

print("Magic Locus progression: bounded cast practice, metric growth, cap and disabled profile passed")
