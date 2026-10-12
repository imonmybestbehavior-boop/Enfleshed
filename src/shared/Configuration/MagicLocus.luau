--!strict

-- Canonical base Locus profile and centralized prototype practice curve.
return {
	Persistence = {
		Enabled = true,
		DataStoreName = "EnfleshedLocusProfileV1",
		SaveInterval = 60,
		MaxPersistedStrain = 1000000,
	},
	Default = {
		Capacity = 300,
		Efficiency = 1,
		Potency = 1,
		StrainTolerance = 30,
		ComplexityCapacity = 8,
	},
	-- Named special pools are distinct from Mana and Strain. This development
	-- registry entry demonstrates authoring and can be extended by server config.
	SpecialResources = {
		Focus = {
			Label = "Focus",
			Capacity = 100,
			Starting = 100,
			RecoveryPerSecond = 4,
			Attribute = "MagicFocus",
		},
	},
	-- Retained as a separately testable curve, but disabled in this unrestricted
	-- mechanics sandbox so casting never raises player stats.
	Progression = {
		Enabled = false,
		PracticeCastsPerRank = 25,
		MaximumRank = 12,
		PerRank = {
			Capacity = 15,
			Efficiency = 0.015,
			Potency = 0.015,
			StrainTolerance = 1.5,
			ComplexityCapacity = 0.25,
		},
	},
}
