--!strict
-- Public combat progression. Studio's unrestricted spell workshop is separate.
return {
	StartingSlots = 4,
	SlotMilestones = { { Slots = 6, XP = 500 }, { Slots = 9, XP = 1800 } },
	Unlocks = {
		AdvancedForms = { Name = "Advanced Forms", XP = 250, Marks = 80, Label = "Fields, auras, waves and constructs" },
		AdvancedBehaviors = {
			Name = "Advanced Behaviors",
			XP = 600,
			Marks = 140,
			Label = "Projectile behaviors and complex triggers",
		},
		AdvancedEffects = {
			Name = "Advanced Effects",
			XP = 1000,
			Marks = 200,
			Label = "Control, summons and specialist effects",
		},
		VisualCraft = { Name = "Visual Craft", XP = 350, Marks = 60, Label = "Expanded spell appearance" },
	},
	UnlockOrder = { "AdvancedForms", "AdvancedBehaviors", "AdvancedEffects", "VisualCraft" },
	RankPrices = { 100, 200, 350 },
	RankXP = { 0, 450, 1200 },
	-- Server-calculated limits for a spell's total upfront cost and complexity.
	RankManaLimits = { 45, 70, 105, 160 },
	RankStrainLimits = { 25, 40, 65, 100 },
	RankComplexityLimits = { 8, 12, 17, 26 },
}
