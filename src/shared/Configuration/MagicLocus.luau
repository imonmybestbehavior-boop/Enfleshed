--!strict

-- Canonical Locus (mana/strain) profiles. Resources are per-session and never persisted.
return {
	Default = {
		Capacity = 300,
		Efficiency = 1,
		Potency = 1,
		StrainTolerance = 30,
		ComplexityCapacity = 8,
	},
	-- Fixed arena combat resource envelope. Power comes from earned spell options,
	-- not from raising these character stats over time.
	Combat = {
		Capacity = 300,
		Efficiency = 1,
		Potency = 1,
		StrainTolerance = 100,
		ComplexityCapacity = 26,
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
}
