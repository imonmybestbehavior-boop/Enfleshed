--!strict

-- Unrestricted test profiles map the Magic Focus to existing registered spells.
return table.freeze({
	RecruitGeneric = {
		ProfileId = "RecruitGeneric",
		Label = "Recruit Focus",
		Description = "The focus's reliable training bolts and discharge.",
		PrimarySpellId = "RecruitMagicBolt",
		AreaSpellId = "RecruitMagicDischarge",
	},
	Fire = {
		ProfileId = "Fire",
		Label = "Fire Focus",
		Description = "Fireball for a focused shot; Burning Ground for area pressure.",
		PrimarySpellId = "Fireball",
		AreaSpellId = "BurningGround",
	},
	Earth = {
		ProfileId = "Earth",
		Label = "Earth Focus",
		Description = "Stone Shot for a focused strike; Stone Raise for an area construct.",
		PrimarySpellId = "StoneShot",
		AreaSpellId = "StoneRaise",
	},
	BodyEnhancement = {
		ProfileId = "BodyEnhancement",
		Label = "Body Focus",
		Description = "Body Burst for close pressure; Body Reinforcement for self enhancement.",
		PrimarySpellId = "BodyBurst",
		AreaSpellId = "BodyReinforcement",
	},
})
