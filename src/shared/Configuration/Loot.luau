--!strict

-- Loot rarity, affix and drop-table data. Rolling logic lives in ItemRules.
return table.freeze({
	-- Ordered lowest to highest. Weight is the base roll weight; Affixes is how
	-- many distinct affixes a rollable item of that rarity receives.
	Rarities = {
		{ Id = "Common", Name = "Common", Weight = 60, Affixes = 0, Color = Color3.fromRGB(190, 190, 190) },
		{ Id = "Uncommon", Name = "Uncommon", Weight = 28, Affixes = 1, Color = Color3.fromRGB(110, 200, 110) },
		{ Id = "Rare", Name = "Rare", Weight = 10, Affixes = 2, Color = Color3.fromRGB(95, 150, 235) },
		{ Id = "Relic", Name = "Relic", Weight = 2, Affixes = 3, Color = Color3.fromRGB(235, 175, 60) },
	},
	-- Stat is the key ItemRules reads. Value rolls uniformly in [Min, Max] and is
	-- scaled by RarityScale[rarity] so higher tiers roll stronger affixes.
	-- Kind "Percent" displays as +N%; "Seconds" as +N.NNs; "Flat" as a percentage of reduction.
	RarityScale = { Common = 1, Uncommon = 1, Rare = 1.2, Relic = 1.45 },
	Affixes = {
		Keen = {
			Name = "Keen",
			Stat = "Damage",
			Min = 0.05,
			Max = 0.14,
			Kind = "Percent",
			Categories = { Weapon = true },
		},
		Swift = {
			Name = "Swift",
			Stat = "AttackSpeed",
			Min = 0.05,
			Max = 0.12,
			Kind = "Percent",
			Categories = { Weapon = true },
		},
		Reaching = {
			Name = "Reaching",
			Stat = "Reach",
			Min = 0.06,
			Max = 0.15,
			Kind = "Percent",
			Categories = { Weapon = true },
		},
		Rending = {
			Name = "Rending",
			Stat = "HeavyDamage",
			Min = 0.1,
			Max = 0.25,
			Kind = "Percent",
			Categories = { Weapon = true },
		},
		Riposte = {
			Name = "Riposte",
			Stat = "ParryWindow",
			Min = 0.03,
			Max = 0.07,
			Kind = "Seconds",
			Categories = { Weapon = true },
		},
		Bulwark = {
			Name = "Bulwark",
			Stat = "BlockReduction",
			Min = 0.04,
			Max = 0.1,
			Kind = "Percent",
			Categories = { Weapon = true, Armor = true },
		},
		Warding = {
			Name = "Warding",
			Stat = "Armor",
			Min = 0.02,
			Max = 0.05,
			Kind = "Percent",
			Categories = { Armor = true },
		},
	},
	MaxArmor = 0.5, -- Total armour damage reduction cap.
	PickupOwnerSeconds = 20, -- Only the killer may collect a drop until this elapses.
	PickupLifetime = 120,
	-- Drop tables keyed by enemy MissionRole. Chance is per kill; each roll picks
	-- one entry by weight. RarityBonus shifts weight toward higher tiers.
	Tables = {
		Basic = {
			Chance = 0.35,
			Rolls = 1,
			RarityBonus = 0,
			Entries = {
				{ ItemId = "EnfleshedTissue", Weight = 40, Count = { 1, 3 } },
				{ ItemId = "FieldDressing", Weight = 20, Count = { 1, 2 } },
				{ ItemId = "WallwardLongsword", Weight = 8 },
				{ ItemId = "ThornKnife", Weight = 8 },
				{ ItemId = "GuardHalfHelm", Weight = 6 },
				{ ItemId = "PaddedGambeson", Weight = 5 },
				{ ItemId = "WardenGreaves", Weight = 5 },
			},
		},
		Swift = {
			Chance = 0.45,
			Rolls = 1,
			RarityBonus = 0.5,
			Entries = {
				{ ItemId = "EnfleshedTissue", Weight = 30, Count = { 1, 3 } },
				{ ItemId = "FieldDressing", Weight = 15, Count = { 1, 2 } },
				{ ItemId = "ThornKnife", Weight = 14 },
				{ ItemId = "LinePike", Weight = 8 },
				{ ItemId = "WallwardLongsword", Weight = 8 },
				{ ItemId = "WardenGreaves", Weight = 6 },
			},
		},
		Brute = {
			Chance = 0.65,
			Rolls = 1,
			RarityBonus = 1,
			Entries = {
				{ ItemId = "EnfleshedTissue", Weight = 25, Count = { 2, 5 } },
				{ ItemId = "FieldDressing", Weight = 15, Count = { 1, 3 } },
				{ ItemId = "BreachersGreatsword", Weight = 12 },
				{ ItemId = "NotchedFalchion", Weight = 10 },
				{ ItemId = "PaddedGambeson", Weight = 8 },
				{ ItemId = "GuardHalfHelm", Weight = 6 },
			},
		},
		Elite = {
			Chance = 1,
			Rolls = 2,
			RarityBonus = 2,
			Entries = {
				{ ItemId = "EnfleshedTissue", Weight = 15, Count = { 3, 6 } },
				{ ItemId = "BreachersGreatsword", Weight = 10 },
				{ ItemId = "NotchedFalchion", Weight = 10 },
				{ ItemId = "LinePike", Weight = 10 },
				{ ItemId = "WallwardLongsword", Weight = 8 },
				{ ItemId = "PaddedGambeson", Weight = 6 },
				{ ItemId = "GuardHalfHelm", Weight = 6 },
				{ ItemId = "WardenGreaves", Weight = 6 },
			},
		},
	},
})
